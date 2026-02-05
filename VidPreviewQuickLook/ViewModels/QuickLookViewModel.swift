//
//  QuickLookViewModel.swift
//  VidPreviewQuickLook
//
//

import Foundation
import Observation
import Quartz
import SwiftUI
import VidCore
import os

private let logger = Logger(subsystem: "com.vidpreview.quicklook", category: "viewmodel")

private final class TaskBox: @unchecked Sendable {
  var value: Task<Void, Never>?
}

@Observable
@MainActor
class QuickLookViewModel {
  // MARK: - Player

  let player = VideoPlayer(buffers: .auto)
  private let url: URL

  // MARK: - UI State (QuickLook-specific)

  var isScrubbing: Bool = false
  private(set) var isFinishingScrub: Bool = false
  private(set) var playbackWasActiveBeforeScrub: Bool = false
  private(set) var userManuallyPaused: Bool = false

  // MARK: - Passthrough Properties

  var playbackState: PlaybackState { player.state }
  var currentFrame: VideoFrame? { player.currentFrame }
  var currentTime: Double {
    get { player.currentTime }
    set { /* Only settable during scrubbing for UI purposes */  }
  }
  var duration: Double { player.duration }
  var videoInfo: VideoInfo? { player.videoInfo }
  var isPlaying: Bool { player.isPlaying }

  var volume: Double {
    get { player.volume }
    set { player.volume = newValue }
  }

  private var preMuteVolume: Double = 1.0

  func toggleMute() {
    if volume > 0 {
      preMuteVolume = volume
      volume = 0
    } else {
      volume = preMuteVolume > 0 ? preMuteVolume : 1.0
    }
  }

  /// Shows pause button if playing, or if we were playing before scrubbing started
  var shouldShowPauseButton: Bool {
    isPlaying || ((isScrubbing || isFinishingScrub) && playbackWasActiveBeforeScrub)
  }

  // MARK: - Initialization

  init(url: URL) {
    self.url = url
    logger.debug("[QuickLookViewModel] Created for: \(url.lastPathComponent)")
  }

  // MARK: - Video Loading

  func loadVideo() async {
    do {
      try await player.load(url: url)
      logger.info(
        "[QuickLookViewModel] Video loaded: \(self.videoInfo?.width ?? 0)x\(self.videoInfo?.height ?? 0)"
      )
    } catch {
      logger.error("[QuickLookViewModel] Failed to load video: \(error.localizedDescription)")
    }
  }

  // MARK: - Playback Control

  func play(manually: Bool = false) {
    if manually {
      userManuallyPaused = false
    }
    player.play()
  }

  func pause(manually: Bool = false) {
    if manually {
      userManuallyPaused = true
    }
    player.pause()
  }

  func togglePlayPause() {
    if isPlaying {
      pause(manually: true)
    } else {
      play(manually: true)
    }
  }

  // MARK: - Scrubbing

  nonisolated private let scrubTaskBox = TaskBox()
  nonisolated private let finishingScrubTaskBox = TaskBox()

  func startScrubbing() {
    // Only modify state if we aren't already in a scrubbing lifecycle
    if !isScrubbing && !isFinishingScrub {
      isScrubbing = true
      playbackWasActiveBeforeScrub = isPlaying
      if isPlaying {
        pause()
      }
    } else if isFinishingScrub {
      // Re-entering scrubbing while still finishing the previous one.
      // Cancel the "finish" task to keep it in a scrubbing state.
      finishingScrubTaskBox.value?.cancel()
      isFinishingScrub = false
      isScrubbing = true
      // playbackWasActiveBeforeScrub is already preserved from the previous start
    }
  }

  func scrub(to time: Double) {
    // Cancel any pending inaccurate seek
    scrubTaskBox.value?.cancel()

    scrubTaskBox.value = Task {
      // Debounce slightly to avoid flooding the decoder during rapid dragging
      try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms
      if Task.isCancelled { return }

      await player.seek(to: time, accurate: false)
    }
  }

  func endScrubbing(at time: Double) {
    scrubTaskBox.value?.cancel()
    finishingScrubTaskBox.value?.cancel()

    isScrubbing = false
    isFinishingScrub = true

    finishingScrubTaskBox.value = Task {
      // Perform final accurate seek
      await player.seek(to: time, accurate: true)

      if Task.isCancelled { return }

      if playbackWasActiveBeforeScrub {
        play()
      }
      isFinishingScrub = false
    }
  }

  // MARK: - Cleanup

  nonisolated func cleanupSync() {
    player.cancelAllTasks()
    scrubTaskBox.value?.cancel()
    finishingScrubTaskBox.value?.cancel()
    player.closeSync()  // Synchronously release decoder, audio, and renderer cache
  }

  nonisolated deinit {
    print("[QuickLookViewModel] DEINIT - deallocating")
    cleanupSync()
  }

  // MARK: - Audio Track Selection

  /// All available audio tracks in the current video.
  var audioTracks: [AudioTrackInfo] {
    player.audioTracks
  }

  /// Index of the currently selected audio track.
  var selectedAudioTrackIndex: Int {
    player.selectedAudioTrackIndex
  }

  /// Select an audio track by its index.
  func selectAudioTrack(at index: Int) async {
    await player.selectAudioTrack(at: index)
  }

  // MARK: - Subtitle Track Selection

  /// All available subtitle tracks in the current video.
  var subtitleTracks: [SubtitleTrackInfo] {
    player.subtitleTracks
  }

  /// Index of the currently selected subtitle track.
  var selectedSubtitleTrackIndex: Int {
    player.selectedSubtitleTrackIndex
  }

  /// Select a subtitle track by its index.
  func selectSubtitleTrack(at index: Int) async {
    await player.selectSubtitleTrack(at: index)
  }
}
