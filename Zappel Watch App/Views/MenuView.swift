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
                    TitleView()
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

/// The name, with a caterpillar crawling along behind it.
private struct TitleView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let unit = size.height / 3
                let travel = size.width + unit * 8
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let lead = reduceMotion ? size.width * 0.8 : (elapsed * unit * 1.6).truncatingRemainder(dividingBy: travel) - unit
                for index in (0..<6).reversed() {
                    let x = lead - Double(index) * unit * 0.9
                    let bob = reduceMotion ? 0 : sin(elapsed * 8 - Double(index)) * unit * 0.12
                    let center = CGPoint(x: x, y: size.height * 0.62 + bob)
                    let radius = unit * (index == 0 ? 0.55 : 0.48)
                    let circle = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                        width: radius * 2, height: radius * 2))
                    context.fill(circle, with: .color(Palette.times[0].caterpillar.color.opacity(0.55)))
                    if index == 0 {
                        for dx in [0.15, 0.4] {
                            let eye = CGRect(x: center.x + radius * dx, y: center.y - radius * 0.25,
                                             width: radius * 0.3, height: radius * 0.3)
                            context.fill(Path(ellipseIn: eye), with: .color(.black.opacity(0.6)))
                        }
                    }
                }
            }
        }
        .frame(height: 44)
        .overlay {
            Text("Zappel")
                .font(.title2.bold())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Zappel")
        .accessibilityAddTraits(.isHeader)
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
