// SettingsView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct SettingsView: View {
    @AppStorage(StorageKey.soundOn) private var soundOn = false
    @AppStorage(StorageKey.hapticsOn) private var hapticsOn = true
    @AppStorage(StorageKey.bestScore) private var best = 0
    @State private var isConfirmingReset = false

    var body: some View {
        List {
            Toggle("Sound", isOn: $soundOn)
            Toggle("Haptics", isOn: $hapticsOn)
            Button("Reset Best Score", role: .destructive) { isConfirmingReset = true }
                .disabled(best == 0)
        }
        .navigationTitle("Settings")
        .onChange(of: soundOn) {
            if !soundOn {
                Sound.shared.stop()
            }
        }
        .alert("Reset the best score?", isPresented: $isConfirmingReset) {
            Button("Reset", role: .destructive) { HighScoreStore.reset() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
