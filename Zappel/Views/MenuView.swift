// MenuView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct MenuView: View {
    @AppStorage(StorageKey.bestScore) private var best = 0
    @State private var isPlaying = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                TitleView(height: 96, font: .largeTitle.bold())
                if best > 0 {
                    Text("Best \(best)")
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { isPlaying = true } label: {
                    Text("Play")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Palette.times[0].caterpillar.color)
                .foregroundStyle(.black)
                NavigationLink("How to Play") { HowToPlayView() }
                NavigationLink("Settings") { SettingsView() }
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .fullScreenCover(isPresented: $isPlaying) {
            GameContainerView { isPlaying = false }
        }
        #if DEBUG
        .onAppear {
            isPlaying = CommandLine.arguments.contains("--play")
        }
        #endif
    }
}

private struct HowToPlayView: View {
    var body: some View {
        List {
            row("hand.draw", "Slide a finger left and right to move the sprinkler.")
            row("drop.fill", "The sprinkler sprays water all by itself.")
            row("camera.macro", "Turn every caterpillar into butterflies and save the garden.")
            row("pause.circle", "Tap the garden to pause.")
        }
        .navigationTitle("How to Play")
    }

    private func row(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(Palette.water.color)
        }
    }
}
