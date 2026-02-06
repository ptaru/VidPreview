//
//  PlayerWindow.swift
//  VidPreview
//
//  Created by User on 2026-02-06.
//

import SwiftUI
import VidPreviewQuickLook

struct PlayerWindow: View {
  let url: URL
  @State private var viewModel: QuickLookViewModel?

  var body: some View {
    Group {
      if let viewModel {
        QuickLookPlayerView(viewModel: viewModel)
      } else {
        ProgressView()
      }
    }
    .task {
      // Initialize VM and load video
      let vm = QuickLookViewModel(url: url)
      self.viewModel = vm
      await vm.loadVideo()
      vm.play()
    }
    .onDisappear {
      // Cleanup when window closes
      viewModel?.cleanupSync()
    }
    .frame(minWidth: 400, minHeight: 300)
  }
}
