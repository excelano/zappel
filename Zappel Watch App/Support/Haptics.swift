// Haptics.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import WatchKit

@MainActor
enum Haptics {
    static func play(_ type: WKHapticType) {
        guard UserDefaults.standard.object(forKey: StorageKey.hapticsOn) as? Bool ?? true else { return }
        WKInterfaceDevice.current().play(type)
    }
}
