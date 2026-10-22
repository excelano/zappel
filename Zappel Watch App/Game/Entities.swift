// Entities.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Positions are in cells. Grid cells are integers, row 0 at the top; creatures that
// move smoothly carry a Double position whose cell is its floor.

struct Cell: Hashable {
    var col: Int
    var row: Int
}

struct Segment {
    var cell: Cell
    /// Where the segment was before its last step, for drawing the move in between.
    var previous: Cell
}

struct Caterpillar {
    /// Head first; each segment steps into the cell of the one ahead of it.
    var segments: [Segment]
    /// -1 moving left, +1 moving right.
    var direction: Int
    /// +1 while working down the garden, -1 while climbing back up inside the player zone.
    var vertical: Int
    /// Sliding straight down after touching a slippery flower.
    var isDiving: Bool

    init(segments: [Segment], direction: Int, vertical: Int = 1, isDiving: Bool = false) {
        self.segments = segments
        self.direction = direction
        self.vertical = vertical
        self.isDiving = isDiving
    }
}

struct Flower {
    /// Hits left: 3 full bloom, 2 half, 1 bud.
    var health: Int
    var isSlippery: Bool

    static let bloom = Flower(health: Rules.flowerHealth, isSlippery: false)
    static let bud = Flower(health: 1, isSlippery: false)

    var isDamaged: Bool { health < Rules.flowerHealth || isSlippery }
}

struct Bee {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
}

struct Acorn {
    var col: Int
    var y: Double
    var isCracked: Bool
    /// The last row the acorn has passed into, so each cell gets one planting roll.
    var row: Int

    var x: Double { Double(col) + 0.5 }
}

struct Snail {
    var x: Double
    var row: Int
    var vx: Double

    var y: Double { Double(row) + 0.5 }
}

struct Drop {
    var col: Int
    /// The tip of the drop, in rows.
    var y: Double
    /// The lowest row not yet passed, checked again each tick so nothing slips under it.
    var row: Int

    var x: Double { Double(col) + 0.5 }
}

struct Player {
    /// Center of the sprinkler, continuous within `Rules.playerRange`.
    var x: Double
}

struct Input {
    var playerX: Double
}

enum GameEvent {
    case dropFired
    case segmentHit(Cell, isHead: Bool)
    case flowerHit(Cell)
    case beeHit(x: Double, y: Double, points: Int)
    case acornCracked
    case acornRolled(x: Double, y: Double, points: Int)
    case snailHit(x: Double, y: Double, points: Int)
    case flowerRestored(Cell)
    case lifeLost
    case extraLife
    case waveCleared
    case waveStarted(Int)
    case gameOver
}
