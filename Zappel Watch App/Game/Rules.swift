// Rules.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

enum Rules {
    static let columns = 10
    static let playerZoneRows = 2
    static let timestep = 1.0 / 60.0

    /// Where the sprinkler's center may go, in cells.
    static let playerRange = 0.5...(Double(columns) - 0.5)

    static let startingLives = 3
    static let maxLives = 6
    static let extraLifeEvery = 12_000

    static let chainLength = 10
    static let maxExtraHeads = 4
    static let maxCaterpillars = 10
    static let sideSpawnInterval = 6.0

    static let initialFlowers = 10
    static let flowerHealth = 3

    /// The drop crosses the whole screen in this many seconds.
    static let dropCrossing = 0.35

    static let beeSpeed = 3.0
    static let beeClimb = 2.5
    static let beeDelay = 8.0...14.0

    static let acornFirstWave = 2
    static let acornSpeed = 6.0
    static let acornThreshold = 3
    static let acornPlantChance = 0.25
    static let acornCooldown = 4.0

    static let snailFirstWave = 3
    static let snailSpeed = 2.0
    static let snailInterval = 15.0
    static let snailChance = 0.5

    static let lifeLostFreeze = 0.5
    static let repairStep = 0.08
    static let waveClearedPause = 1.5

    static let bodyPoints = 10
    static let headPoints = 100
    static let flowerPoints = 1
    static let acornPoints = 200
    static let snailPoints = 1000
    static let restorePoints = 5

    /// Seconds per cell step for the caterpillars.
    static func moveInterval(wave: Int) -> Double {
        max(0.07, 0.3 - 0.015 * Double(wave - 1))
    }

    static func extraHeads(wave: Int) -> Int {
        min(wave - 1, maxExtraHeads)
    }

    /// Bee points by how many rows above the player's row it was hit.
    static func beePoints(rowsAbovePlayer: Int) -> Int {
        switch rowsAbovePlayer {
        case ...0: 900
        case 1: 600
        default: 300
        }
    }
}
