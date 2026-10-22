// GameOverView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct GameResult {
    let score: Int
    let best: Int
    let isNewBest: Bool
}

struct GameOverView: View {
    let result: GameResult
    let onPlayAgain: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text("Game Over")
                    .font(.headline)
                Text("\(result.score)")
                    .font(.title.bold().monospacedDigit())
                Text(result.isNewBest ? "New best!" : "Best \(result.best)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(result.isNewBest ? Palette.flowerCenter.color : .secondary)
                Button("Play Again", action: onPlayAgain)
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.times[0].caterpillar.color)
                    .foregroundStyle(.black)
                Button("Menu", action: onMenu)
            }
            .padding(.horizontal, 12)
            .padding(.top, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.8))
    }
}
