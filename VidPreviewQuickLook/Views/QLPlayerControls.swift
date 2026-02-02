//
//  QLPlayerControls.swift
//  VidPreviewQuickLook
//

import SwiftUI
import VidCore

struct QLPlayerControls: View {
  @Bindable var viewModel: QuickLookViewModel
  @State private var seekPosition: Double = 0.0

  var body: some View {
    HStack(spacing: 12) {
      Button(action: {
        viewModel.togglePlayPause()
      }) {
        Image(systemName: playButtonIcon)
          .font(.title2)
          .frame(width: 32, height: 32)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(viewModel.playbackState == .loading || viewModel.playbackState == .idle)

      Text(
        formatTime(
          viewModel.isScrubbing ? seekPosition : viewModel.currentTime, duration: viewModel.duration
        )
      )
      .font(.caption)
      .monospacedDigit()
      .onChange(of: viewModel.currentTime) { _, newValue in
        if !viewModel.isScrubbing && !viewModel.isFinishingScrub {
          seekPosition = newValue
        }
      }

      if viewModel.duration > 0 && viewModel.duration.isFinite {
        Slider(
          value: $seekPosition,
          in: 0...viewModel.duration,
          onEditingChanged: { editing in
            if editing {
              viewModel.startScrubbing()
              viewModel.scrub(to: seekPosition)
            } else {
              viewModel.endScrubbing(at: seekPosition)
            }
          }
        )
        .onChange(of: seekPosition) { _, newValue in
          if viewModel.isScrubbing {
            viewModel.scrub(to: newValue)
          }
        }
        .disabled(viewModel.playbackState == .loading || viewModel.playbackState == .idle)
      } else {
        RoundedRectangle(cornerRadius: 2)
          .fill(Color.white)
          .frame(height: 4)
      }

      Text(formatTime(viewModel.duration, duration: viewModel.duration))
        .font(.caption)
        .monospacedDigit()
        .padding(.trailing, 8)
    }
    .padding(8)
  }

  private var playButtonIcon: String {
    if viewModel.playbackState == .finished {
      return "arrow.counterclockwise"
    } else if viewModel.shouldShowPauseButton {
      return "pause.fill"
    } else {
      return "play.fill"
    }
  }

  private func formatTime(_ seconds: Double, duration: Double) -> String {
    let totalSeconds = Int(max(0, seconds))
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60

    if duration >= 3600 {
      return String(format: "%d:%02d:%02d", hours, minutes, secs)
    } else if duration >= 600 {
      return String(format: "%02d:%02d", minutes, secs)
    } else {
      return String(format: "%d:%02d", minutes, secs)
    }
  }
}
