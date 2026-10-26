// MenuView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct MenuView: View {
    @AppStorage(StorageKey.bestScore) private var best = 0
    @State private var isPlaying = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    TitleView(height: 44, font: .title2.bold())
                    if best > 0 {
                        Text("Best \(best)")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Button("Play") { isPlaying = true }
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.times[0].caterpillar.color)
                        .foregroundStyle(.black)
                    NavigationLink("How to Play") { HowToPlayView() }
                    NavigationLink("Settings") { SettingsView() }
                }
            }
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
        TabView {
            page("digitalcrown.arrow.counterclockwise", "Turn the Crown, or slide a finger, to move the sprinkler.")
            page("drop.fill", "The sprinkler sprays water all by itself.")
            page("camera.macro", "Turn every caterpillar into butterflies and save the garden.")
        }
        .tabViewStyle(.verticalPage)
        .navigationTitle("How to Play")
    }

    private func page(_ symbol: String, _ text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(Palette.water.color)
            Text(text)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal)
    }
}
