// HighScoreStore.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

enum StorageKey {
    static let bestScore = "bestScore"
    static let soundOn = "soundOn"
    static let hapticsOn = "hapticsOn"
}

enum HighScoreStore {
    static var best: Int {
        UserDefaults.standard.integer(forKey: StorageKey.bestScore)
    }

    /// Keeps the score if it beats the best, and returns whether it did.
    @discardableResult
    static func record(score: Int) -> Bool {
        guard score > best else { return false }
        UserDefaults.standard.set(score, forKey: StorageKey.bestScore)
        return true
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: StorageKey.bestScore)
    }
}
