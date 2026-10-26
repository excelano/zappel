// OverlayPanel.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

/// Buttons over the dimmed garden: centered where they fit, scrolling below the clock where they do not.
struct OverlayPanel<Content: View>: View {
    let dimming: Double
    @ViewBuilder let content: Content

    var body: some View {
        ViewThatFits(in: .vertical) {
            stack
            ScrollView {
                stack.padding(.top, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(dimming))
    }

    private var stack: some View {
        VStack(spacing: 6) {
            content
        }
        .padding(.horizontal, 12)
    }
}
