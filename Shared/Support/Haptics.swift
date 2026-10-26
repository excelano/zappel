// Haptics.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
#if os(watchOS)
import WatchKit
#else
import UIKit
#endif

@MainActor
enum Haptics {
    enum Effect {
        case click
        case success
        case failure
        case notification
    }

    static func play(_ effect: Effect) {
        guard UserDefaults.standard.object(forKey: StorageKey.hapticsOn) as? Bool ?? true else { return }
        #if os(watchOS)
        let type: WKHapticType = switch effect {
        case .click: .click
        case .success: .success
        case .failure: .failure
        case .notification: .notification
        }
        WKInterfaceDevice.current().play(type)
        #else
        switch effect {
        case .click: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .failure: UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .notification: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        #endif
    }
}
