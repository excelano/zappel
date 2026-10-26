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
        OverlayPanel(dimming: 0.8) {
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
    }
}
