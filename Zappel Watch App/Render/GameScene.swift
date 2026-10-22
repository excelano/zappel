// GameScene.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Draws the model. Each frame it steps the model, moves pooled sprites to match, then
// turns the model's events into effects, haptics and sound. It decides nothing about play.

import SpriteKit
import UIKit

@MainActor
final class GameScene: SKScene {
    let model: GameModel
    /// Where the player is steering the sprinkler, in cells.
    var playerTarget: Double
    var onGameOver: ((_ score: Int, _ wave: Int) -> Void)?
    var reduceMotion = false
    var isGamePaused = false {
        didSet {
            lastTime = nil
            isPaused = isGamePaused
        }
    }

    private let cell: CGFloat
    private let gridTop: CGFloat
    private let textures: Textures
    private var palette: Palette
    private var caterpillarTextures: CaterpillarTextures

    private let background = SKSpriteNode()
    private let flowerLayer = SKNode()
    private let creatureLayer = SKNode()
    private let effectLayer = SKNode()
    private let hudLayer = SKNode()

    private var flowerNodes: [SKSpriteNode?]
    private var flowerKeys: [Int]
    private var segmentNodes: [SKSpriteNode] = []
    private let stand: SKSpriteNode
    private let sprinkler: SKSpriteNode
    private let dropNode: SKSpriteNode
    private let beeNode: SKSpriteNode
    private let acornNode: SKSpriteNode
    private let snailNode: SKSpriteNode
    private var effectNodes: [SKSpriteNode] = []
    private var popupNodes: [SKLabelNode] = []
    private let scoreLabel = SKLabelNode()
    private var lifeNodes: [SKSpriteNode] = []
    private let banner = SKLabelNode()

    private var shownScore = -1
    private var shownLives = -1
    private var lastTime: TimeInterval?
    private var clock: TimeInterval = 0
    private var hadBee = false

    /// Cells of lawn below the bottom row, lifting the sprinkler clear of the rounded corners.
    static let bottomMargin = 0.5

    private static let effectLimit = 40
    private static let popupLimit = 6
    private static let spinKey = "spin"

    init(size: CGSize, model: GameModel, scale: CGFloat) {
        self.model = model
        playerTarget = model.player.x
        cell = size.width / CGFloat(model.columns)
        gridTop = (CGFloat(model.rows) + Self.bottomMargin) * cell
        textures = Textures(cell: cell, scale: scale)
        palette = Palette.forWave(model.wave)
        caterpillarTextures = textures.caterpillar(palette.caterpillar)
        flowerNodes = Array(repeating: nil, count: model.flowers.count)
        flowerKeys = Array(repeating: 0, count: model.flowers.count)
        stand = SKSpriteNode(texture: textures.sprinklerStand, size: textures.segmentSize)
        sprinkler = SKSpriteNode(texture: textures.sprinklerHead, size: textures.sprinklerHeadSize)
        dropNode = SKSpriteNode(texture: textures.drop, size: textures.dropSize)
        beeNode = SKSpriteNode(texture: textures.beeFrames[0], size: textures.beeSize)
        acornNode = SKSpriteNode(texture: textures.acorn, size: textures.acornSize)
        snailNode = SKSpriteNode(texture: textures.snail, size: textures.snailSize)
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .black
        buildNodes()
    }

    required init?(coder: NSCoder) {
        fatalError("GameScene is built in code")
    }

    private func buildNodes() {
        background.anchorPoint = .zero
        background.size = size
        background.zPosition = 0
        addChild(background)
        paintBackground()

        for (layer, z) in [(flowerLayer, 1), (creatureLayer, 2), (effectLayer, 4), (hudLayer, 5)] {
            layer.zPosition = CGFloat(z)
            addChild(layer)
        }
        stand.zPosition = 3
        addChild(stand)
        sprinkler.zPosition = 3.1
        addChild(sprinkler)
        spinSprinkler()

        for node in [dropNode, beeNode, acornNode, snailNode] {
            node.isHidden = true
            creatureLayer.addChild(node)
        }

        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.verticalAlignmentMode = .center
        let hudY = (gridTop - cell + size.height) / 2
        scoreLabel.position = CGPoint(x: cell * 2, y: hudY)
        hudLayer.addChild(scoreLabel)
        for index in 0..<Rules.maxLives {
            let icon = SKSpriteNode(texture: textures.lifeIcon, size: CGSize(width: cell * 0.9, height: cell * 0.9))
            icon.position = CGPoint(x: size.width * 0.4 + cell * 0.85 * CGFloat(index), y: hudY)
            lifeNodes.append(icon)
            hudLayer.addChild(icon)
        }

        banner.horizontalAlignmentMode = .center
        banner.verticalAlignmentMode = .center
        banner.position = CGPoint(x: size.width / 2, y: size.height * 0.55)
        banner.alpha = 0
        hudLayer.addChild(banner)
        showBanner("Wave \(model.wave)")
    }

    // MARK: - Frame

    /// SpriteKit calls this on the main thread, though its declaration does not say so.
    nonisolated override func update(_ currentTime: TimeInterval) {
        nonisolated(unsafe) let scene = self
        MainActor.assumeIsolated { scene.advance(to: currentTime) }
    }

    private func advance(to currentTime: TimeInterval) {
        guard !isGamePaused else {
            lastTime = nil
            return
        }
        let dt = lastTime.map { currentTime - $0 } ?? 0
        lastTime = currentTime
        clock += dt
        model.step(dt: dt, input: Input(playerX: playerTarget))
        sync()
        handleEvents()
    }

    private func point(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: CGFloat(x) * cell, y: gridTop - CGFloat(y) * cell)
    }

    private func sync() {
        syncFlowers()
        syncCaterpillars()

        stand.position = point(model.player.x, Double(model.bottomRow) + 0.5)
        sprinkler.position = CGPoint(x: stand.position.x, y: stand.position.y + cell * 0.22)

        if let drop = model.drop {
            dropNode.isHidden = false
            dropNode.position = point(drop.x, drop.y + 0.33)
        } else {
            dropNode.isHidden = true
        }

        if let bee = model.bee {
            beeNode.isHidden = false
            beeNode.position = point(bee.x, bee.y)
            beeNode.xScale = bee.vx < 0 ? -1 : 1
            beeNode.texture = textures.beeFrames[Int(clock * 14) % 2]
            if !hadBee {
                Sound.shared.play(.buzz)
            }
        } else {
            beeNode.isHidden = true
        }
        hadBee = model.bee != nil

        if let acorn = model.acorn {
            acornNode.isHidden = false
            acornNode.position = point(acorn.x, acorn.y)
            acornNode.texture = acorn.isCracked ? textures.acornCracked : textures.acorn
        } else {
            acornNode.isHidden = true
        }

        if let snail = model.snail {
            snailNode.isHidden = false
            snailNode.position = point(snail.x, snail.y)
            snailNode.xScale = snail.vx < 0 ? -1 : 1
        } else {
            snailNode.isHidden = true
        }

        if model.score != shownScore {
            shownScore = model.score
            scoreLabel.attributedText = Self.text("\(model.score)", size: cell * 0.95)
        }
        if model.lives != shownLives {
            shownLives = model.lives
            for (index, icon) in lifeNodes.enumerated() {
                icon.isHidden = index >= model.lives
            }
        }
    }

    private func syncFlowers() {
        for index in model.flowers.indices {
            let flower = model.flowers[index]
            let key = flower.map { $0.health + ($0.isSlippery ? 4 : 0) } ?? 0
            guard key != flowerKeys[index] else { continue }
            flowerKeys[index] = key
            guard let flower else {
                flowerNodes[index]?.isHidden = true
                continue
            }
            let cell = model.cell(at: index)
            let node = flowerNodes[index] ?? makeFlowerNode(at: cell, index: index)
            node.isHidden = false
            node.texture = textures.flower(color: cell.col * 7 + cell.row * 3, health: flower.health,
                                           slippery: flower.isSlippery)
        }
    }

    private func makeFlowerNode(at cell: Cell, index: Int) -> SKSpriteNode {
        let node = SKSpriteNode(texture: nil, size: textures.segmentSize)
        node.position = point(Double(cell.col) + 0.5, Double(cell.row) + 0.5)
        flowerLayer.addChild(node)
        flowerNodes[index] = node
        return node
    }

    private func syncCaterpillars() {
        let progress = model.moveProgress
        var used = 0
        for caterpillar in model.caterpillars {
            for (index, segment) in caterpillar.segments.enumerated() {
                if used == segmentNodes.count {
                    let node = SKSpriteNode(texture: nil, size: textures.segmentSize)
                    segmentNodes.append(node)
                    creatureLayer.addChild(node)
                }
                let node = segmentNodes[used]
                used += 1
                guard segment.cell.row >= model.topRow else {
                    node.isHidden = true
                    continue
                }
                node.isHidden = false
                let x = Double(segment.previous.col) + Double(segment.cell.col - segment.previous.col) * progress
                let y = Double(segment.previous.row) + Double(segment.cell.row - segment.previous.row) * progress
                node.position = point(x + 0.5, y + 0.5)
                node.zPosition = index == 0 ? 1 : 0
                node.texture = index == 0 ? caterpillarTextures.head : caterpillarTextures.body
                node.xScale = index == 0 && caterpillar.direction < 0 ? -1 : 1
            }
        }
        for node in segmentNodes[used...] where !node.isHidden {
            node.isHidden = true
        }
    }

    // MARK: - Events

    private func handleEvents() {
        for event in model.events {
            switch event {
            case .dropFired:
                Sound.shared.play(.plip)
            case .segmentHit(let cell, let isHead):
                releaseButterfly(at: point(Double(cell.col) + 0.5, Double(cell.row) + 0.5), rise: 3)
                Sound.shared.play(.chime)
                if isHead {
                    Haptics.play(.click)
                }
            case .flowerHit, .acornCracked:
                break
            case .beeHit(let x, let y, let points):
                fly(textures.beeFrames[0], size: textures.beeSize, from: point(x, y), by: CGVector(dx: 0, dy: cell * 5), spin: 0)
                popup(points, at: point(x, y))
            case .acornRolled(let x, let y, let points):
                let away: CGFloat = x < Double(model.columns) / 2 ? -1 : 1
                fly(textures.acornCracked, size: textures.acornSize, from: point(x, y),
                    by: CGVector(dx: away * cell * 6, dy: 0), spin: -away * .pi * 4)
                popup(points, at: point(x, y))
            case .snailHit(let x, let y, let points):
                let away: CGFloat = x < Double(model.columns) / 2 ? -1 : 1
                fly(textures.shell, size: textures.shellSize, from: point(x, y),
                    by: CGVector(dx: away * cell * 9, dy: 0), spin: -away * .pi * 6)
                popup(points, at: point(x, y))
            case .flowerRestored(let cell):
                let index = cell.row * model.columns + cell.col
                flowerNodes[index]?.run(.sequence([.scale(to: 1.35, duration: 0.05), .scale(to: 1, duration: 0.1)]))
            case .lifeLost:
                Haptics.play(.failure)
                sputter()
            case .extraLife:
                Haptics.play(.notification)
            case .waveCleared:
                Haptics.play(.success)
                if !reduceMotion {
                    shower()
                }
            case .waveStarted(let wave):
                startWave(wave)
            case .gameOver:
                onGameOver?(model.score, model.wave)
            }
        }
    }

    private func startWave(_ wave: Int) {
        palette = Palette.forWave(wave)
        caterpillarTextures = textures.caterpillar(palette.caterpillar)
        paintBackground()
        spinSprinkler()
        showBanner("Wave \(wave)")
    }

    private func paintBackground() {
        background.texture = textures.background(size: size, palette: palette, gridTop: gridTop, rows: model.rows,
                                                 playerZoneTop: model.playerZoneTop)
    }

    private func spinSprinkler() {
        sprinkler.alpha = 1
        guard sprinkler.action(forKey: Self.spinKey) == nil else { return }
        sprinkler.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 0.8)), withKey: Self.spinKey)
    }

    private func sputter() {
        sprinkler.removeAction(forKey: Self.spinKey)
        sprinkler.alpha = 0.55
        let shake = CGFloat(cell * 0.15)
        stand.run(.repeat(.sequence([.moveBy(x: shake, y: 0, duration: 0.04), .moveBy(x: -shake, y: 0, duration: 0.04)]), count: 5))
    }

    private func showBanner(_ text: String) {
        banner.attributedText = Self.text(text, size: cell * 1.4)
        banner.removeAllActions()
        banner.alpha = 1
        banner.run(.sequence([.wait(forDuration: 0.9), .fadeOut(withDuration: 0.4)]))
    }

    // MARK: - Effects

    private func effectNode(_ texture: SKTexture, size: CGSize, at position: CGPoint) -> SKSpriteNode? {
        let node: SKSpriteNode
        if let free = effectNodes.first(where: { $0.isHidden }) {
            node = free
        } else if effectNodes.count < Self.effectLimit {
            node = SKSpriteNode()
            effectNodes.append(node)
            effectLayer.addChild(node)
        } else {
            return nil
        }
        node.texture = texture
        node.size = size
        node.position = position
        node.alpha = 1
        node.zRotation = 0
        node.isHidden = false
        return node
    }

    private func releaseButterfly(at position: CGPoint, rise: CGFloat, delay: TimeInterval = 0, duration: TimeInterval = 0.6) {
        guard let node = effectNode(caterpillarTextures.wingsOpen, size: textures.butterflySize, at: position) else { return }
        let drift = CGFloat.random(in: -1.5...1.5) * cell
        let flap = SKAction.repeat(.animate(with: [caterpillarTextures.wingsOpen, caterpillarTextures.wingsClosed],
                                            timePerFrame: 0.08), count: Int(duration / 0.16) + 1)
        let flight = SKAction.group([
            flap,
            .moveBy(x: drift, y: rise * cell, duration: duration),
            .sequence([.wait(forDuration: duration * 0.6), .fadeOut(withDuration: duration * 0.4)]),
        ])
        node.alpha = delay > 0 ? 0 : 1
        node.run(.sequence([.wait(forDuration: delay), .fadeIn(withDuration: 0), flight, .hide()]))
    }

    private func fly(_ texture: SKTexture, size: CGSize, from position: CGPoint, by vector: CGVector, spin: CGFloat) {
        guard let node = effectNode(texture, size: size, at: position) else { return }
        let duration = 0.7
        node.run(.sequence([
            .group([.move(by: vector, duration: duration), .rotate(byAngle: spin, duration: duration),
                    .sequence([.wait(forDuration: duration * 0.5), .fadeOut(withDuration: duration * 0.5)])]),
            .hide(),
        ]))
    }

    private func popup(_ points: Int, at position: CGPoint) {
        let node: SKLabelNode
        if let free = popupNodes.first(where: { $0.isHidden }) {
            node = free
        } else if popupNodes.count < Self.popupLimit {
            node = SKLabelNode()
            node.verticalAlignmentMode = .center
            popupNodes.append(node)
            effectLayer.addChild(node)
        } else {
            return
        }
        node.attributedText = Self.text("\(points)", size: cell * 0.9)
        node.position = CGPoint(x: min(max(position.x, cell * 2), size.width - cell * 2), y: position.y + cell)
        node.alpha = 1
        node.isHidden = false
        let fade = SKAction.sequence([.wait(forDuration: 0.5), .fadeOut(withDuration: 0.3)])
        let motion = reduceMotion ? fade : .group([.moveBy(x: 0, y: cell * 1.5, duration: 0.8), fade])
        node.run(.sequence([motion, .hide()]))
    }

    /// The wave-cleared celebration: butterflies rise across the whole garden.
    private func shower() {
        for index in 0..<14 {
            let x = CGFloat.random(in: cell...(size.width - cell))
            releaseButterfly(at: CGPoint(x: x, y: cell * CGFloat.random(in: 1...5)), rise: CGFloat(model.rows),
                             delay: Double(index) * 0.06, duration: 1.2)
        }
    }

    private static func text(_ string: String, size: CGFloat) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [
            .font: UIFont.monospacedDigitSystemFont(ofSize: size, weight: .heavy),
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor(white: 0.1, alpha: 1),
            .strokeWidth: -4,
        ])
    }
}
