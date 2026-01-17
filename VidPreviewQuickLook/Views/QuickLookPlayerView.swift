//
//  QuickLookPlayerView.swift
//  VidPreviewQuickLook
//
//  Simplified QuickLook player view using VidPlayer
//

import SwiftUI
import VidCore

struct QuickLookPlayerView: View {
    @Bindable var viewModel: QuickLookViewModel
    @State private var isHovering = false
    @State private var forceShowControls = false
    @State private var hideTask: Task<Void, Never>?
    
    private var shouldShowControls: Bool {
        isHovering || forceShowControls || viewModel.playbackState == .finished
    }
    
    var body: some View {
        VidPlayer(player: viewModel.player) {
            // Controls overlay - just the bottom bar and volume
            VStack {
                HStack {
                    Spacer()
                    QLVolumeControl(viewModel: viewModel)
                        .glassedEffect(in: .capsule, interactive: true)
                        .padding(8)
                        .opacity(shouldShowControls ? 1 : 0)
                }
                
                Spacer()
                
                QLPlayerControls(viewModel: viewModel)
                    .glassedEffect(in: .capsule, interactive: true)
                    .padding(8)
                    .opacity(shouldShowControls ? 1 : 0)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onChange(of: viewModel.isPlaying) { _, _ in
            showControlsTemporarily()
        }
        .onChange(of: viewModel.playbackState) { _, newState in
            if newState == .finished {
                withAnimation(.easeInOut(duration: 0.3)) {
                    forceShowControls = true
                }
            }
        }
    }
    
    private func showControlsTemporarily() {
        hideTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            forceShowControls = true
        }
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !Task.isCancelled && viewModel.playbackState != .finished {
                withAnimation(.easeInOut(duration: 0.2)) {
                    forceShowControls = false
                }
            }
        }
    }
}
