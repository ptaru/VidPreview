//
//  SettingsView.swift
//  VidPreview
//
//  QuickLook Extension Settings & About View
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
  @Environment(\.openWindow) private var openWindow
  @State private var isTargeted = false

  var body: some View {
    VStack(spacing: 24) {
      // App Icon and Title
      VStack(spacing: 12) {
        Image(systemName: "eye.fill")
          .font(.system(size: 64))
          .foregroundStyle(.blue)

        Text("VidPreview")
          .font(.largeTitle)
          .fontWeight(.bold)

        Text("QuickLook Extension for Video Files")
          .font(.title3)
          .foregroundStyle(.secondary)
      }
      .padding(.top, 40)

      Divider()
        .padding(.horizontal, 40)

      // Instructions
      VStack(alignment: .leading, spacing: 16) {
        Text("How to Use")
          .font(.headline)

        HStack(alignment: .top, spacing: 12) {
          Image(systemName: "1.circle.fill")
            .foregroundStyle(.blue)
          Text("Select a video file in Finder")
        }

        HStack(alignment: .top, spacing: 12) {
          Image(systemName: "2.circle.fill")
            .foregroundStyle(.blue)
          Text("Press **Space** to preview with QuickLook")
        }

        HStack(alignment: .top, spacing: 12) {
          Image(systemName: "3.circle.fill")
            .foregroundStyle(.blue)
          Text("Enjoy full video playback in the preview!")
        }
      }
      .frame(maxWidth: 300, alignment: .leading)

      Divider()
        .padding(.horizontal, 40)

      // Supported Formats
      VStack(spacing: 12) {
        Text("Supported Formats")
          .font(.headline)

        VStack(spacing: 8) {
          HStack(spacing: 12) {
            FormatBadge(format: "MKV")
            FormatBadge(format: "MP4")
            FormatBadge(format: "MOV")
            FormatBadge(format: "AVI")
            FormatBadge(format: "WebM")
          }
          HStack(spacing: 12) {
            FormatBadge(format: "FLV")
            FormatBadge(format: "WMV")
            FormatBadge(format: "VOB")
            FormatBadge(format: "TS")
            FormatBadge(format: "OGG")
          }
        }
      }

      // Footer
      Text("Made by Tarun")
        .font(.caption)
        .foregroundStyle(.tertiary)
        .padding(.bottom, 16)
    }
    .frame(minWidth: 400, maxWidth: 400)
    .background(Color(nsColor: .windowBackgroundColor))
    .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
      guard let provider = providers.first else { return false }

      provider.loadObject(ofClass: URL.self) { url, error in
        if let url = url {
          DispatchQueue.main.async {
            BookmarkManager.shared.saveBookmark(for: url)
            openWindow(value: url)
          }
        }
      }
      return true
    }
  }
}

struct FormatBadge: View {
  let format: String

  var body: some View {
    Text(format)
      .font(.caption)
      .fontWeight(.medium)
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(.blue.opacity(0.1))
      .foregroundStyle(.blue)
      .clipShape(RoundedRectangle(cornerRadius: 6))
  }
}

#Preview {
  SettingsView()
}
