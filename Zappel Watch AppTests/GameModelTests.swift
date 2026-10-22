// GameModelTests.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Testing
@testable import Zappel_Watch_App

/// An empty garden 20 rows tall (player zone rows 18 and 19), with no bee or acorn
/// coming, the player in column 8, and a one-segment caterpillar parked at the top
/// left so the wave does not end on the first tick.
func garden() -> GameModel {
    let game = GameModel(rows: 20, seed: 7, populated: false)
    game.beeTimer = .infinity
    game.acornCooldown = .infinity
    game.player.x = 8.5
    game.caterpillars = [caterpillar(at: [(0, 1)], direction: 1)]
    return game
}

func caterpillar(at cells: [(Int, Int)], direction: Int) -> Caterpillar {
    Caterpillar(segments: cells.map {
        let cell = Cell(col: $0.0, row: $0.1)
        return Segment(cell: cell, previous: cell)
    }, direction: direction)
}

func tick(_ game: GameModel) {
    game.step(dt: Rules.timestep, input: Input(playerX: game.player.x))
}

/// Puts a drop just below the cell and lets it travel through that cell alone.
func shoot(_ game: GameModel, col: Int, row: Int) {
    game.drop = Drop(col: col, y: Double(row) + 0.99, row: row)
    tick(game)
}

/// Ticks until the first caterpillar's head steps.
func nextMove(_ game: GameModel) {
    let start = game.caterpillars[0].segments[0].cell
    for _ in 0..<60 where game.caterpillars[0].segments[0].cell == start {
        tick(game)
    }
}

struct CaterpillarMovementTests {
    @Test func dropsAndReversesAtTheWall() {
        let game = garden()
        game.caterpillars = [caterpillar(at: [(0, 3), (1, 3)], direction: -1)]
        nextMove(game)
        #expect(game.caterpillars[0].segments[0].cell == Cell(col: 0, row: 4))
        #expect(game.caterpillars[0].segments[1].cell == Cell(col: 0, row: 3))
        #expect(game.caterpillars[0].direction == 1)
        nextMove(game)
        #expect(game.caterpillars[0].segments[0].cell == Cell(col: 1, row: 4))
    }

    @Test func dropsAndReversesAtAFlower() {
        let game = garden()
        game.caterpillars = [caterpillar(at: [(5, 3)], direction: 1)]
        game.setFlower(.bloom, at: Cell(col: 6, row: 3))
        nextMove(game)
        #expect(game.caterpillars[0].segments[0].cell == Cell(col: 5, row: 4))
        #expect(game.caterpillars[0].direction == -1)
    }

    @Test func slipperyFlowerSendsItStraightDownToThePlayerZone() {
        let game = garden()
        game.caterpillars = [caterpillar(at: [(5, 3)], direction: 1)]
        game.setFlower(Flower(health: 3, isSlippery: true), at: Cell(col: 6, row: 3))
        for row in 4...game.playerZoneTop {
            nextMove(game)
            #expect(game.caterpillars[0].segments[0].cell == Cell(col: 5, row: row))
        }
        nextMove(game)
        #expect(game.caterpillars[0].segments[0].cell == Cell(col: 6, row: game.playerZoneTop))
        #expect(!game.caterpillars[0].isDiving)
    }

    @Test func bouncesInsideThePlayerZone() {
        let game = garden()
        game.player.x = 0.5
        game.caterpillars = [caterpillar(at: [(9, 19)], direction: 1)]
        nextMove(game)
        #expect(game.caterpillars[0].segments[0].cell == Cell(col: 9, row: 18))
        #expect(game.caterpillars[0].vertical == -1)
    }

    @Test func waveOneIsOneFullChain() {
        let game = GameModel(rows: 20, seed: 1)
        #expect(game.caterpillars.count == 1)
        #expect(game.caterpillars[0].segments.count == Rules.chainLength)
    }
}

struct HitTests {
    @Test func hittingAMiddleSegmentSplitsTheChain() {
        let game = garden()
        game.caterpillars = [caterpillar(at: [(8, 5), (7, 5), (6, 5), (5, 5), (4, 5), (3, 5)], direction: 1)]
        shoot(game, col: 6, row: 5)
        #expect(game.caterpillars.count == 2)
        let front = game.caterpillars[0]
        let back = game.caterpillars[1]
        #expect(front.segments.map(\.cell) == [Cell(col: 8, row: 5), Cell(col: 7, row: 5)])
        #expect(front.direction == 1)
        #expect(back.segments.map(\.cell) == [Cell(col: 5, row: 5), Cell(col: 4, row: 5), Cell(col: 3, row: 5)])
        #expect(back.direction == 1)
        #expect(game.flower(at: Cell(col: 6, row: 5))?.health == 1)
        #expect(game.score == Rules.bodyPoints)
    }

    @Test func hittingAHeadScoresMoreAndPromotesTheNextSegment() {
        let game = garden()
        game.caterpillars = [caterpillar(at: [(8, 5), (7, 5), (6, 5)], direction: 1)]
        shoot(game, col: 8, row: 5)
        #expect(game.caterpillars.count == 1)
        #expect(game.caterpillars[0].segments[0].cell == Cell(col: 7, row: 5))
        #expect(game.score == Rules.headPoints)
    }

    @Test func flowerTakesThreeHitsAtOnePointEach() {
        let game = garden()
        let cell = Cell(col: 8, row: 10)
        game.setFlower(.bloom, at: cell)
        for health in [2, 1] {
            shoot(game, col: 8, row: 10)
            #expect(game.flower(at: cell)?.health == health)
        }
        shoot(game, col: 8, row: 10)
        #expect(game.flower(at: cell) == nil)
        #expect(game.score == 3)
    }

    @Test func onlyOneDropAtATime() {
        let game = GameModel(rows: 20, seed: 3)
        var fired = 0
        for step in 0..<600 {
            let hadDrop = game.drop != nil
            game.step(dt: Rules.timestep, input: Input(playerX: 8 + 6 * sin(Double(step) / 40)))
            let fires = game.events.filter { if case .dropFired = $0 { true } else { false } }.count
            #expect(fires <= 1)
            #expect(!(hadDrop && fires > 0))
            fired += fires
        }
        #expect(fired > 10)
    }
}

struct CreatureTests {
    @Test func acornWaitsForTheSecondWave() {
        let game = garden()
        game.acornCooldown = 0
        for _ in 0..<30 { tick(game) }
        #expect(game.acorn == nil)
    }

    @Test func acornComesOnlyWhenThePlayerZoneIsBare() {
        let game = garden()
        game.wave = Rules.acornFirstWave
        for col in 0..<Rules.acornThreshold {
            game.setFlower(.bloom, at: Cell(col: col * 2 + 1, row: game.playerZoneTop))
        }
        game.acornCooldown = 0
        for _ in 0..<30 { tick(game) }
        #expect(game.acorn == nil)

        game.setFlower(nil, at: Cell(col: 1, row: game.playerZoneTop))
        tick(game)
        #expect(game.acorn != nil)
    }

    @Test func acornNeedsTwoHits() throws {
        let game = garden()
        game.acorn = Acorn(col: 3, y: 5.2, isCracked: false, row: 5)

        shoot(game, col: 3, row: 5)
        let cracked = try #require(game.acorn)
        #expect(cracked.isCracked)
        #expect(game.score == 0)

        shoot(game, col: cracked.col, row: Int(cracked.y))
        #expect(game.acorn == nil)
        #expect(game.score == Rules.acornPoints)
    }

    @Test(arguments: [(0, 900), (1, 600), (2, 300)])
    func beeScoresByDistance(rowsAbove: Int, points: Int) {
        #expect(Rules.beePoints(rowsAbovePlayer: rowsAbove) == points)
        let game = garden()
        let row = game.bottomRow - rowsAbove
        game.bee = Bee(x: 3.5, y: Double(row) + 0.5, vx: 0, vy: 0)
        shoot(game, col: 3, row: row)
        #expect(game.bee == nil)
        #expect(game.score == points)
    }
}

struct LivesTests {
    @Test func extraLifeEveryTwelveThousandUpToSix() {
        let game = garden()
        game.addScore(11_990)
        #expect(game.lives == 3)
        game.addScore(10)
        #expect(game.lives == 4)
        game.addScore(48_000)
        #expect(game.lives == Rules.maxLives)
        #expect(game.nextExtraLife == 72_000)
    }

    @Test func losingALifeRestoresTheGardenAtFivePointsEach() {
        let game = garden()
        game.setFlower(.bud, at: Cell(col: 3, row: 5))
        game.setFlower(Flower(health: 3, isSlippery: true), at: Cell(col: 4, row: 7))
        game.setFlower(.bloom, at: Cell(col: 2, row: 9))
        game.caterpillars.append(caterpillar(at: [(8, 19), (7, 19)], direction: 1))

        tick(game)
        #expect(game.lives == 2)
        #expect(game.phase == .losingLife(remaining: Rules.lifeLostFreeze))

        for _ in 0..<60 { tick(game) }
        #expect(game.phase == .playing)
        #expect(game.flowers.compactMap { $0 }.allSatisfy { $0.health == 3 && !$0.isSlippery })
        #expect(game.score == 2 * Rules.restorePoints)
        #expect(game.caterpillars.reduce(0) { $0 + $1.segments.count } == 3)
    }

    @Test func lastLifeEndsTheGame() {
        let game = garden()
        for _ in 0..<Rules.startingLives {
            for _ in 0..<90 where game.phase != .playing { tick(game) }
            game.caterpillars = [caterpillar(at: [(0, 1)], direction: 1), caterpillar(at: [(8, 19)], direction: 1)]
            for _ in 0..<90 where game.phase == .playing { tick(game) }
        }
        for _ in 0..<90 where game.phase != .gameOver { tick(game) }
        #expect(game.lives == 0)
        #expect(game.phase == .gameOver)
    }
}
