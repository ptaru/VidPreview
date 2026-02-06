//
//  VidPreviewApp.swift
//  VidPreview
//
//  QuickLook Extension Host App
//

import SwiftUI

@main
struct VidPreviewApp: App {
  var body: some Scene {
    WindowGroup {
      SettingsView()
    }
    .windowResizability(.contentSize)

    WindowGroup(for: URL.self) { $url in
      if let url {
        PlayerWindow(url: url)
          .navigationTitle(url.lastPathComponent)
      }
    }
  }
}
