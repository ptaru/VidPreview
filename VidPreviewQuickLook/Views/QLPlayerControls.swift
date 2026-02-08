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
                    viewModel.isScrubbing ? seekPosition : viewModel.currentTime,
                    duration: viewModel.duration
                )
            )
            .font(.caption)
            .monospacedDigit()
            .onChange(of: viewModel.currentTime) { _, newValue in
                if !viewModel.isScrubbing {
                    seekPosition = newValue
                }
            }

            if viewModel.duration > 0 && viewModel.duration.isFinite {
                GeometryReader { geometry in
                    let sliderWidth = geometry.size.width

                    ZStack {
                        // Background track
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 4)

                        // Progress track
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white)
                            .frame(
                                width: max(
                                    0,
                                    min(
                                        CGFloat(seekPosition / viewModel.duration) * sliderWidth,
                                        sliderWidth)),
                                height: 4
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Thumb
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                            .position(
                                x: max(
                                    6,
                                    min(
                                        CGFloat(seekPosition / viewModel.duration) * sliderWidth,
                                        sliderWidth - 6)),
                                y: 10
                            )
                            .shadow(radius: 2)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !viewModel.isScrubbing {
                                    viewModel.beginScrub()
                                }
                                let percent = max(0, min(value.location.x / sliderWidth, 1.0))
                                seekPosition = Double(percent) * viewModel.duration
                                viewModel.scrub(to: seekPosition)
                            }
                            .onEnded { _ in
                                viewModel.endScrub()
                            }
                    )
                }
                .frame(height: 20)
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
        } else if viewModel.isPlaying {
            return "pause.fill"
        } else {
            return "play.fill"
        }
    }

    private func formatTime(_ seconds: Double, duration: Double) -> String {
        guard seconds.isFinite, duration.isFinite else { return "--:--" }
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
