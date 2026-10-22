// Rules.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

enum Rules {
    static let columns = 16
    static let playerZoneRows = 4
    static let timestep = 1.0 / 60.0

    static let startingLives = 3
    static let maxLives = 6
    static let extraLifeEvery = 12_000

    static let chainLength = 12
    static let maxExtraHeads = 4
    static let maxCaterpillars = 10
    static let sideSpawnInterval = 6.0

    static let initialFlowers = 30
    static let flowerHealth = 3

    /// The drop crosses the whole screen in this many seconds.
    static let dropCrossing = 0.35

    static let beeSpeed = 5.0
    static let beeClimb = 4.0
    static let beeDelay = 6.0...10.0

    static let acornSpeed = 8.0
    static let acornThreshold = 5
    static let acornPlantChance = 0.25
    static let acornCooldown = 1.5

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
        max(0.07, 0.12 - 0.005 * Double(wave - 1))
    }

    static func extraHeads(wave: Int) -> Int {
        min(wave - 1, maxExtraHeads)
    }

    /// Bee points by how many rows above the player's row it was hit.
    static func beePoints(rowsAbovePlayer: Int) -> Int {
        switch rowsAbovePlayer {
        case ...1: 900
        case 2: 600
        default: 300
        }
    }
}
