//
//  QuickLookPlayerView.swift
//  VidPreviewQuickLook
//

import SwiftUI
import VidCore

struct QuickLookPlayerView: View {
  @Bindable var viewModel: QuickLookViewModel
  @State private var isHovering = false
  @State private var forceShowControls = false
  @State private var hideTask: Task<Void, Never>?
  @State private var isTrackMenuVisible = false

  private var shouldShowControls: Bool {
    isHovering || forceShowControls || isTrackMenuVisible || viewModel.playbackState == .finished
  }

  var body: some View {
    VidPlayer(player: viewModel.player, allowsDebugMenu: true) {
      // Controls overlay - volume, audio track selector, and bottom bar
      VStack {
        HStack {
          Spacer()
          HStack(spacing: 8) {
            if viewModel.audioTracks.count > 0 || viewModel.subtitleTracks.count > 0 {
              QLTrackSelector(viewModel: viewModel, isMenuPresented: $isTrackMenuVisible)
                .glassedEffect(in: .rect(cornerRadius: 8), interactive: true)
            }
            QLVolumeControl(viewModel: viewModel)
              .glassedEffect(in: .rect(cornerRadius: 8), interactive: true)
          }
          .padding(8)
          .opacity(shouldShowControls ? 1 : 0)
        }

        Spacer()

        QLPlayerControls(viewModel: viewModel)
          .glassedEffect(in: .rect(cornerRadius: 8), interactive: true)
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
