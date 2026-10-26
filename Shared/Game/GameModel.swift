// GameModel.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

final class GameModel {
    enum Phase: Equatable {
        case playing
        /// The freeze after the player is touched.
        case losingLife(remaining: Double)
        /// Restoring damaged flowers one at a time before the wave restarts.
        case repairing(nextIn: Double)
        case waveCleared(remaining: Double)
        case gameOver
    }

    let columns = Rules.columns
    let rows: Int
    /// Row 0 holds the score; the garden starts below it.
    let topRow = 1
    let bottomRow: Int
    let playerZoneTop: Int
    /// The bee zigzags through the player zone and the row above it.
    var beeTopRow: Int { playerZoneTop - 1 }

    private(set) var phase = Phase.playing
    private(set) var score = 0
    private(set) var lives = Rules.startingLives
    var wave = 1
    private(set) var nextExtraLife = Rules.extraLifeEvery

    var flowers: [Flower?]
    var caterpillars: [Caterpillar] = []
    var player: Player
    var drop: Drop?
    var bee: Bee?
    var acorn: Acorn?
    var snail: Snail?

    /// What happened during the last call to step, for sound, haptics and effects.
    private(set) var events: [GameEvent] = []

    private var rng: SplitMix64
    private var accumulator = 0.0
    private var moveClock = 0.0
    var beeTimer: Double
    var acornCooldown = 0.0
    var snailTimer = Rules.snailInterval
    var sideSpawnTimer = 0.0

    /// How far the caterpillars are through their current step, 0 to 1.
    var moveProgress: Double { min(1, moveClock / Rules.moveInterval(wave: wave)) }

    /// A new game, or with `populated` false an empty garden for tests to arrange.
    init(rows: Int, seed: UInt64, populated: Bool = true) {
        precondition(rows >= Rules.playerZoneRows + 6, "the garden is too short")
        self.rows = rows
        bottomRow = rows - 1
        playerZoneTop = rows - Rules.playerZoneRows
        flowers = Array(repeating: nil, count: rows * Rules.columns)
        player = Player(x: Double(Rules.columns) / 2)
        rng = SplitMix64(seed: seed)
        beeTimer = Double.random(in: Rules.beeDelay, using: &rng)
        events.reserveCapacity(32)
        if populated {
            plantInitialFlowers()
            spawnCaterpillars(total: Rules.chainLength)
        }
    }

    // MARK: - Time

    func step(dt: Double, input: Input) {
        events.removeAll(keepingCapacity: true)
        accumulator += min(dt, 0.25)
        while accumulator >= Rules.timestep {
            accumulator -= Rules.timestep
            tick(input)
        }
    }

    private func tick(_ input: Input) {
        let dt = Rules.timestep
        switch phase {
        case .playing:
            movePlayer(to: input.playerX)
            tickPlaying(dt)
        case .losingLife(let remaining):
            if remaining > dt {
                phase = .losingLife(remaining: remaining - dt)
            } else if lives == 0 {
                phase = .gameOver
                events.append(.gameOver)
            } else {
                phase = .repairing(nextIn: Rules.repairStep)
            }
        case .repairing(let nextIn):
            movePlayer(to: input.playerX)
            if nextIn > dt {
                phase = .repairing(nextIn: nextIn - dt)
            } else if let index = flowers.firstIndex(where: { $0?.isDamaged == true }) {
                flowers[index] = .bloom
                events.append(.flowerRestored(cell(at: index)))
                addScore(Rules.restorePoints)
                phase = .repairing(nextIn: Rules.repairStep)
            } else {
                restartWave()
            }
        case .waveCleared(let remaining):
            movePlayer(to: input.playerX)
            if remaining > dt {
                phase = .waveCleared(remaining: remaining - dt)
            } else {
                wave += 1
                spawnCaterpillars(total: Rules.chainLength)
                phase = .playing
                events.append(.waveStarted(wave))
            }
        case .gameOver:
            break
        }
    }

    private func tickPlaying(_ dt: Double) {
        moveClock += dt
        let interval = Rules.moveInterval(wave: wave)
        if moveClock >= interval {
            moveClock -= interval
            for index in caterpillars.indices {
                stepCaterpillar(&caterpillars[index])
            }
        }
        moveDrop(dt)
        moveBee(dt)
        moveAcorn(dt)
        moveSnail(dt)
        spawnSideHead(dt)

        if isPlayerTouched() {
            loseLife()
        } else if caterpillars.isEmpty {
            drop = nil
            phase = .waveCleared(remaining: Rules.waveClearedPause)
            events.append(.waveCleared)
        }
    }

    private func movePlayer(to x: Double) {
        player.x = min(max(x, Rules.playerRange.lowerBound), Rules.playerRange.upperBound)
    }

    // MARK: - Caterpillars

    private func stepCaterpillar(_ caterpillar: inout Caterpillar) {
        let next = nextHeadCell(&caterpillar)
        for index in caterpillar.segments.indices.reversed() {
            caterpillar.segments[index].previous = caterpillar.segments[index].cell
            caterpillar.segments[index].cell = index == 0 ? next : caterpillar.segments[index - 1].cell
        }
    }

    private func nextHeadCell(_ caterpillar: inout Caterpillar) -> Cell {
        let head = caterpillar.segments[0].cell
        if head.row < topRow {
            return Cell(col: head.col, row: head.row + 1)
        }
        if caterpillar.isDiving {
            if head.row < playerZoneTop {
                return Cell(col: head.col, row: head.row + 1)
            }
            caterpillar.isDiving = false
        }
        let ahead = Cell(col: head.col + caterpillar.direction, row: head.row)
        guard ahead.col >= 0, ahead.col < columns else { return turn(&caterpillar, from: head) }
        guard let blocker = flower(at: ahead) else { return ahead }
        if blocker.isSlippery && head.row < playerZoneTop {
            caterpillar.isDiving = true
            return Cell(col: head.col, row: head.row + 1)
        }
        return turn(&caterpillar, from: head)
    }

    /// Drops a row (or climbs one, when bouncing inside the player zone) and reverses.
    private func turn(_ caterpillar: inout Caterpillar, from head: Cell) -> Cell {
        caterpillar.direction = -caterpillar.direction
        if caterpillar.vertical > 0 && head.row >= bottomRow {
            caterpillar.vertical = -1
        } else if caterpillar.vertical < 0 && head.row <= playerZoneTop {
            caterpillar.vertical = 1
        }
        return Cell(col: head.col, row: head.row + caterpillar.vertical)
    }

    /// Lays out a wave's caterpillars above the garden, to crawl in from the top.
    private func spawnCaterpillars(total: Int) {
        let extras = min(Rules.extraHeads(wave: wave), total - 1)
        let mainLength = total - extras
        let start = Int.random(in: 4...(columns - 5), using: &rng)
        let segments = (0..<mainLength).map { index in
            let cell = Cell(col: start, row: topRow - 1 - index)
            return Segment(cell: cell, previous: cell)
        }
        caterpillars.append(Caterpillar(segments: segments, direction: Bool.random(using: &rng) ? 1 : -1))
        for index in 0..<extras {
            let fromLeft = index.isMultiple(of: 2)
            let cell = Cell(col: fromLeft ? 0 : columns - 1, row: topRow - 1 - 3 * (index / 2))
            caterpillars.append(Caterpillar(segments: [Segment(cell: cell, previous: cell)],
                                            direction: fromLeft ? 1 : -1))
        }
        moveClock = 0
    }

    /// Once the caterpillars have all reached the player zone, a fresh head crawls in from the side now and then.
    private func spawnSideHead(_ dt: Double) {
        let inZone = caterpillars.contains { $0.segments[0].cell.row >= playerZoneTop }
        let entering = caterpillars.contains { $0.segments[0].cell.row < playerZoneTop }
        guard inZone, !entering, caterpillars.count < Rules.maxCaterpillars else {
            sideSpawnTimer = 0
            return
        }
        sideSpawnTimer += dt
        guard sideSpawnTimer >= Rules.sideSpawnInterval else { return }
        sideSpawnTimer = 0
        let fromLeft = Bool.random(using: &rng)
        let cell = Cell(col: fromLeft ? 0 : columns - 1, row: playerZoneTop)
        caterpillars.append(Caterpillar(segments: [Segment(cell: cell, previous: cell)],
                                        direction: fromLeft ? 1 : -1))
    }

    /// The hit segment becomes a butterfly and leaves a bud; the segment behind it leads what is left.
    private func hitSegment(caterpillar index: Int, segment hit: Int) {
        let caterpillar = caterpillars[index]
        let cell = caterpillar.segments[hit].cell
        let isHead = hit == 0
        addScore(isHead ? Rules.headPoints : Rules.bodyPoints)
        events.append(.segmentHit(cell, isHead: isHead))

        let behind = Array(caterpillar.segments[(hit + 1)...])
        if isHead {
            caterpillars.remove(at: index)
        } else {
            caterpillars[index].segments.removeSubrange(hit...)
        }
        if let newHead = behind.first {
            let dx = cell.col - newHead.cell.col
            caterpillars.append(Caterpillar(segments: behind,
                                            direction: dx == 0 ? caterpillar.direction : dx.signum(),
                                            vertical: caterpillar.vertical))
        }
        if flower(at: cell) == nil {
            setFlower(.bud, at: cell)
        }
    }

    // MARK: - The drop

    private func moveDrop(_ dt: Double) {
        guard var current = drop else {
            let col = min(Int(player.x), columns - 1)
            drop = Drop(col: col, y: Double(bottomRow), row: bottomRow)
            events.append(.dropFired)
            return
        }
        current.y -= Double(rows) / Rules.dropCrossing * dt
        let reached = Int(current.y.rounded(.down))
        for row in stride(from: current.row, through: max(reached, topRow), by: -1) {
            if hitSomething(at: Cell(col: current.col, row: row)) {
                drop = nil
                return
            }
        }
        if reached < topRow {
            drop = nil
            return
        }
        current.row = reached
        drop = current
    }

    /// Creatures are checked before flowers, so a bee over a flower takes the hit.
    private func hitSomething(at cell: Cell) -> Bool {
        for index in caterpillars.indices {
            if let hit = caterpillars[index].segments.firstIndex(where: { $0.cell == cell }) {
                hitSegment(caterpillar: index, segment: hit)
                return true
            }
        }
        if let current = bee, overlaps(x: current.x, y: current.y, cell: cell) {
            let points = Rules.beePoints(rowsAbovePlayer: bottomRow - Int(current.y.rounded(.down)))
            addScore(points)
            events.append(.beeHit(x: current.x, y: current.y, points: points))
            bee = nil
            beeTimer = Double.random(in: Rules.beeDelay, using: &rng)
            return true
        }
        if let current = acorn, overlaps(x: current.x, y: current.y, cell: cell) {
            if current.isCracked {
                addScore(Rules.acornPoints)
                events.append(.acornRolled(x: current.x, y: current.y, points: Rules.acornPoints))
                acorn = nil
                acornCooldown = Rules.acornCooldown
            } else {
                acorn?.isCracked = true
                events.append(.acornCracked)
            }
            return true
        }
        if let current = snail, overlaps(x: current.x, y: current.y, cell: cell) {
            addScore(Rules.snailPoints)
            events.append(.snailHit(x: current.x, y: current.y, points: Rules.snailPoints))
            snail = nil
            return true
        }
        if var target = flower(at: cell) {
            target.health -= 1
            setFlower(target.health > 0 ? target : nil, at: cell)
            addScore(Rules.flowerPoints)
            events.append(.flowerHit(cell))
            return true
        }
        return false
    }

    private func overlaps(x: Double, y: Double, cell: Cell) -> Bool {
        abs(x - (Double(cell.col) + 0.5)) < 0.75 && abs(y - (Double(cell.row) + 0.5)) < 0.75
    }

    // MARK: - Bee, acorn and snail

    private func moveBee(_ dt: Double) {
        guard var current = bee else {
            beeTimer -= dt
            if beeTimer <= 0 {
                let fromLeft = Bool.random(using: &rng)
                let y = Double.random(in: Double(beeTopRow) + 0.5...Double(bottomRow) + 0.5, using: &rng)
                bee = Bee(x: fromLeft ? -0.5 : Double(columns) + 0.5, y: y,
                          vx: fromLeft ? Rules.beeSpeed : -Rules.beeSpeed,
                          vy: Bool.random(using: &rng) ? Rules.beeClimb : -Rules.beeClimb)
            }
            return
        }
        current.x += current.vx * dt
        current.y += current.vy * dt
        let top = Double(beeTopRow) + 0.5
        let bottom = Double(bottomRow) + 0.5
        if current.y < top {
            current.y = top
            current.vy = abs(current.vy)
        } else if current.y > bottom {
            current.y = bottom
            current.vy = -abs(current.vy)
        }
        if current.x < -1 || current.x > Double(columns) + 1 {
            bee = nil
            beeTimer = Double.random(in: Rules.beeDelay, using: &rng)
            return
        }
        let cell = Cell(col: Int(current.x.rounded(.down)), row: Int(current.y.rounded(.down)))
        if isInGarden(cell) && flower(at: cell) != nil {
            setFlower(nil, at: cell)
        }
        bee = current
    }

    private func moveAcorn(_ dt: Double) {
        guard var current = acorn else {
            acornCooldown -= dt
            if wave >= Rules.acornFirstWave && acornCooldown <= 0 && flowersInPlayerZone() < Rules.acornThreshold {
                acorn = Acorn(col: Int.random(in: 0..<columns, using: &rng), y: Double(topRow),
                              isCracked: false, row: topRow)
            }
            return
        }
        current.y += Rules.acornSpeed * (current.isCracked ? 2 : 1) * dt
        let reached = Int(current.y.rounded(.down))
        while current.row < reached {
            current.row += 1
            let cell = Cell(col: current.col, row: current.row)
            if current.row < bottomRow && flower(at: cell) == nil
                && Double.random(in: 0..<1, using: &rng) < Rules.acornPlantChance {
                setFlower(.bloom, at: cell)
            }
        }
        if current.y > Double(rows) {
            acorn = nil
            acornCooldown = Rules.acornCooldown
            return
        }
        acorn = current
    }

    private func moveSnail(_ dt: Double) {
        guard var current = snail else {
            guard wave >= Rules.snailFirstWave else { return }
            snailTimer -= dt
            if snailTimer <= 0 {
                snailTimer = Rules.snailInterval
                if Double.random(in: 0..<1, using: &rng) < Rules.snailChance {
                    let fromLeft = Bool.random(using: &rng)
                    snail = Snail(x: fromLeft ? -0.5 : Double(columns) + 0.5,
                                  row: Int.random(in: topRow...(rows / 2), using: &rng),
                                  vx: fromLeft ? Rules.snailSpeed : -Rules.snailSpeed)
                }
            }
            return
        }
        current.x += current.vx * dt
        if current.x < -1 || current.x > Double(columns) + 1 {
            snail = nil
            return
        }
        let cell = Cell(col: Int(current.x.rounded(.down)), row: current.row)
        if isInGarden(cell), var target = flower(at: cell), !target.isSlippery {
            target.isSlippery = true
            setFlower(target, at: cell)
        }
        snail = current
    }

    // MARK: - Lives and waves

    private func isPlayerTouched() -> Bool {
        let playerY = Double(bottomRow) + 0.5
        for caterpillar in caterpillars {
            for segment in caterpillar.segments where segment.cell.row == bottomRow {
                if abs(Double(segment.cell.col) + 0.5 - player.x) < 0.75 { return true }
            }
        }
        if let bee, abs(bee.x - player.x) < 0.75, abs(bee.y - playerY) < 0.75 { return true }
        if let acorn, abs(acorn.x - player.x) < 0.75, abs(acorn.y - playerY) < 0.75 { return true }
        return false
    }

    private func loseLife() {
        lives -= 1
        drop = nil
        phase = .losingLife(remaining: Rules.lifeLostFreeze)
        events.append(.lifeLost)
    }

    /// After repair the wave starts over with as many segments as were left.
    private func restartWave() {
        let remaining = caterpillars.reduce(0) { $0 + $1.segments.count }
        caterpillars.removeAll()
        bee = nil
        acorn = nil
        snail = nil
        beeTimer = Double.random(in: Rules.beeDelay, using: &rng)
        acornCooldown = Rules.acornCooldown
        sideSpawnTimer = 0
        spawnCaterpillars(total: max(remaining, 1))
        phase = .playing
        events.append(.waveStarted(wave))
    }

    func addScore(_ points: Int) {
        score += points
        while score >= nextExtraLife {
            nextExtraLife += Rules.extraLifeEvery
            if lives < Rules.maxLives {
                lives += 1
                events.append(.extraLife)
            }
        }
    }

    // MARK: - Flowers

    func flower(at cell: Cell) -> Flower? {
        isInGarden(cell) ? flowers[cell.row * columns + cell.col] : nil
    }

    func setFlower(_ flower: Flower?, at cell: Cell) {
        guard isInGarden(cell) else { return }
        flowers[cell.row * columns + cell.col] = flower
    }

    func cell(at index: Int) -> Cell {
        Cell(col: index % columns, row: index / columns)
    }

    func isInGarden(_ cell: Cell) -> Bool {
        cell.col >= 0 && cell.col < columns && cell.row >= topRow && cell.row <= bottomRow
    }

    func flowersInPlayerZone() -> Int {
        var count = 0
        for index in (playerZoneTop * columns)..<(rows * columns) where flowers[index] != nil {
            count += 1
        }
        return count
    }

    /// Scattered over the upper garden, never side by side,
    /// leaving the row above the player zone clear.
    private func plantInitialFlowers() {
        let lastRow = playerZoneTop - 2
        var planted = 0
        var attempts = 0
        while planted < Rules.initialFlowers && attempts < 2000 {
            attempts += 1
            let cell = Cell(col: Int.random(in: 0..<columns, using: &rng),
                            row: Int.random(in: 2...lastRow, using: &rng))
            let left = Cell(col: cell.col - 1, row: cell.row)
            let right = Cell(col: cell.col + 1, row: cell.row)
            if flower(at: cell) == nil && flower(at: left) == nil && flower(at: right) == nil {
                setFlower(.bloom, at: cell)
                planted += 1
            }
        }
    }
}
