// GameContainerView.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SpriteKit
import SwiftUI

struct GameContainerView: View {
    let onQuit: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @State private var scene: GameScene?
    @State private var size = CGSize.zero
    @State private var clockInset = 0.0
    @State private var hudHeadroom = 0.0
    @State private var homeIndicatorInset = 0.0
    @State private var isPaused = false
    @State private var result: GameResult?
    @State private var dragOrigin: Double?
    #if os(watchOS)
    @State private var crown = 0.0
    @FocusState private var isCrownFocused: Bool

    /// Cells the sprinkler moves per unit of crown rotation.
    private static let crownGain = 0.08
    #endif

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
                if controlStrip > 0 {
                    Color.clear
                        .frame(height: controlStrip)
                        .contentShape(Rectangle())
                        .gesture(pointing(width: geometry.size.width))
                        .frame(maxHeight: .infinity, alignment: .bottom)
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
                #if os(iOS)
                // The Dynamic Island sits mid-screen, where the watch's clock does not.
                hudHeadroom = safeArea.safeAreaInsets.top
                homeIndicatorInset = safeArea.safeAreaInsets.bottom
                #endif
                if scene == nil {
                    newGame()
                }
            }
            }
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        #if os(watchOS)
        .focusable()
        .focused($isCrownFocused)
        .focusEffectDisabled()
        .digitalCrownRotation($crown, from: -1_000_000, through: 1_000_000, by: nil, sensitivity: .high,
                              isContinuous: false, isHapticFeedbackEnabled: false)
        .onChange(of: crown) { old, new in
            steer(to: (scene?.playerTarget ?? 0) + (new - old) * Self.crownGain)
        }
        // The overlays' buttons take the focus, so it comes back each time play does.
        .onChange(of: isPlaying) {
            if isPlaying {
                isCrownFocused = true
            }
        }
        .onAppear { isCrownFocused = true }
        #else
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .bottom)
        #endif
        .onChange(of: scenePhase) {
            if scenePhase != .active {
                pause()
            }
        }
    }

    private var isPlaying: Bool {
        result == nil && !isPaused
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

    /// A finger on the soil strip puts the sprinkler straight above it.
    private func pointing(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isPaused else { return }
                steer(to: value.location.x / width * Double(Rules.columns))
            }
    }

    /// The soil along the bottom of the iPhone's garden, where a finger steers without covering the sprinkler.
    private var controlStrip: CGFloat {
        #if os(iOS)
        let cell = size.width / CGFloat(Rules.columns)
        return max(2 * cell, homeIndicatorInset + cell)
        #else
        return 0
        #endif
    }

    private func steer(to x: Double) {
        scene?.playerTarget = min(max(x, Rules.playerRange.lowerBound), Rules.playerRange.upperBound)
    }

    private func newGame() {
        guard size.width > 0 else { return }
        // The sky band holding the score row reaches down past the system clock.
        let cell = size.width / CGFloat(Rules.columns)
        let sky = max(clockInset, hudHeadroom + cell)
        let lawn = GameScene.bottomMargin * cell + controlStrip
        let rows = Int((size.height - sky - lawn) / cell) + 1
        let model = GameModel(rows: rows, seed: Self.seed())
        let scene = GameScene(size: size, model: model, scale: displayScale, headroom: hudHeadroom,
                              controlStrip: controlStrip)
        scene.reduceMotion = reduceMotion
        scene.onGameOver = { score in
            let isNewBest = HighScoreStore.record(score: score)
            result = GameResult(score: score, best: HighScoreStore.best, isNewBest: isNewBest)
        }
        self.scene = scene
        result = nil
        isPaused = false
    }

    private func pause() {
        guard result == nil, !isPaused else { return }
        isPaused = true
        scene?.isGamePaused = true
    }

    private func resume() {
        isPaused = false
        scene?.isGamePaused = false
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
        OverlayPanel(dimming: 0.75) {
            Button("Resume", action: onResume)
                .buttonStyle(.borderedProminent)
                .tint(Palette.times[0].caterpillar.color)
                .foregroundStyle(.black)
            Button("Restart", action: onRestart)
            Button("Quit to Menu", action: onQuit)
        }
    }
}
