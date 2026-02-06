//
//  PlayerWindow.swift
//  VidPreview
//

import SwiftUI
import VidPreviewQuickLook

struct PlayerWindow: View {
  let url: URL
  @State private var viewModel: QuickLookViewModel?
  @State private var accessedURL: URL?

  var body: some View {
    Group {
      if let viewModel {
        QuickLookPlayerView(viewModel: viewModel)
      } else {
        ProgressView()
      }
    }
    .task {
      // Try to resolve bookmark permissions first
      var targetURL = url
      if let resolved = BookmarkManager.shared.resolveBookmark(for: url) {
        if resolved.startAccessingSecurityScopedResource() {
          targetURL = resolved
          self.accessedURL = resolved
        }
      }

      // Initialize VM and load video
      let vm = QuickLookViewModel(url: targetURL)
      self.viewModel = vm
      await vm.loadVideo()
      vm.play()
    }
    .onDisappear {
      // Cleanup when window closes
      viewModel?.cleanupSync()
      if let accessedURL {
        accessedURL.stopAccessingSecurityScopedResource()
        self.accessedURL = nil
      }
    }
    .frame(minWidth: 400, minHeight: 300)
  }
}
