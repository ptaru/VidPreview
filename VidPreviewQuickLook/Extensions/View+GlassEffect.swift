//
//  View+GlassEffect.swift
//  VidPreviewQuickLook
//
//  Glass effect for views with backward compatibility
//  Courtesy of https://livsycode.com/swiftui/implementing-the-glasseffect-in-swiftui/
//

import SwiftUI

extension View {
    @ViewBuilder
    func glassedEffect(in shape: some Shape, interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            self.background {
                shape.glassed()
            }
        }
    }
}

extension Shape {
    func glassed() -> some View {
        self
            .fill(.ultraThinMaterial)
            .fill(
                .linearGradient(
                    colors: [
                        .primary.opacity(0.08),
                        .primary.opacity(0.05),
                        .primary.opacity(0.01),
                        .clear,
                        .clear,
                        .clear,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .stroke(.primary.opacity(0.2), lineWidth: 0.7)
    }
}
