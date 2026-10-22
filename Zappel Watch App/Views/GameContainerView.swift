// GameContainerView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SpriteKit
import SwiftUI
import WatchKit

struct GameContainerView: View {
    let onQuit: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene: GameScene?
    @State private var size = CGSize.zero
    @State private var clockInset = 0.0
    @State private var isPaused = false
    @State private var result: GameResult?
    @State private var crown = 0.0
    @State private var dragOrigin: Double?
    @FocusState private var isCrownFocused: Bool

    /// Cells the sprinkler moves per unit of crown rotation.
    private static let crownGain = 1.0

    var body: some View {
        GeometryReader { safeArea in
            GeometryReader { geometry in
            ZStack {
                Color.black
                if let scene {
                    SpriteView(scene: scene, preferredFramesPerSecond: 60)
                        .gesture(steering(width: geometry.size.width))
                        .onTapGesture(perform: pause)
                }
                if let result {
                    GameOverView(result: result, onPlayAgain: newGame, onMenu: onQuit)
                } else if isPaused {
                    PauseOverlay(onResume: resume, onRestart: newGame, onQuit: onQuit)
                }
            }
            .onChange(of: geometry.size, initial: true) {
                size = geometry.size
                clockInset = safeArea.safeAreaInsets.top
                if scene == nil {
                    newGame()
                }
            }
            }
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .focusable()
        .focused($isCrownFocused)
        .focusEffectDisabled()
        .digitalCrownRotation($crown, from: -1_000_000, through: 1_000_000, by: nil, sensitivity: .high,
                              isContinuous: false, isHapticFeedbackEnabled: false)
        .onChange(of: crown) { old, new in
            steer(to: (scene?.playerTarget ?? 0) + (new - old) * Self.crownGain)
        }
        .onChange(of: scenePhase) {
            if scenePhase != .active {
                pause()
            }
        }
        .onAppear { isCrownFocused = true }
    }

    /// A drag moves the sprinkler as far as the finger moves.
    private func steering(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard let scene, !isPaused else { return }
                let origin = dragOrigin ?? scene.playerTarget
                dragOrigin = origin
                steer(to: origin + value.translation.width / width * Double(Rules.columns))
            }
            .onEnded { _ in dragOrigin = nil }
    }

    private func steer(to x: Double) {
        scene?.playerTarget = min(max(x, 0.5), Double(Rules.columns) - 0.5)
    }

    private func newGame() {
        guard size.width > 0 else { return }
        // The sky band holding the score row reaches down past the system clock.
        let cell = size.width / CGFloat(Rules.columns)
        let rows = Int((size.height - max(clockInset, cell)) / cell) + 1
        let model = GameModel(rows: rows, seed: Self.seed())
        let scene = GameScene(size: size, model: model, scale: WKInterfaceDevice.current().screenScale)
        scene.reduceMotion = reduceMotion
        scene.onGameOver = { score, wave in
            let isNewBest = HighScoreStore.record(score: score, wave: wave)
            result = GameResult(score: score, best: HighScoreStore.best, isNewBest: isNewBest)
        }
        self.scene = scene
        result = nil
        isPaused = false
        isCrownFocused = true
    }

    private func pause() {
        guard result == nil, !isPaused else { return }
        isPaused = true
        scene?.isGamePaused = true
    }

    private func resume() {
        isPaused = false
        scene?.isGamePaused = false
        isCrownFocused = true
    }

    private static func seed() -> UInt64 {
        #if DEBUG
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--seed"), index + 1 < arguments.count,
           let seed = UInt64(arguments[index + 1]) {
            return seed
        }
        #endif
        return UInt64.random(in: .min ... .max)
    }
}

private struct PauseOverlay: View {
    let onResume: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Button("Resume", action: onResume)
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.times[0].caterpillar.color)
                    .foregroundStyle(.black)
                Button("Restart", action: onRestart)
                Button("Quit to Menu", action: onQuit)
            }
            .padding(.horizontal, 12)
            .padding(.top, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.75))
    }
}
