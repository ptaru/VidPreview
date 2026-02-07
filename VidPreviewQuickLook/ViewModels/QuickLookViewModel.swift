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

// TaskBox removed as it's no longer needed for internal scrubbing tasks

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

  var volumeSlider: Double {
    get { Self.sliderValue(fromGain: player.volume) }
    set { player.volume = Self.gain(fromSlider: newValue) }
  }

  private var preMuteVolumeSlider: Double = 1.0

  func toggleMute() {
    if volume > 0 {
      preMuteVolumeSlider = volumeSlider
      volume = 0
    } else {
      let restore = preMuteVolumeSlider > 0 ? preMuteVolumeSlider : 1.0
      volumeSlider = restore
    }
  }

  private static let minVolumeDb: Double = -50.0

  private static func gain(fromSlider value: Double) -> Double {
    let clamped = max(0.0, min(value, 1.0))
    if clamped == 0 {
      return 0
    }
    let db = minVolumeDb + (0 - minVolumeDb) * clamped
    return pow(10.0, db / 20.0)
  }

  private static func sliderValue(fromGain gain: Double) -> Double {
    let clamped = max(0.0, min(gain, 1.0))
    if clamped == 0 {
      return 0
    }
    let db = 20.0 * log10(clamped)
    let slider = (db - minVolumeDb) / (0 - minVolumeDb)
    return max(0.0, min(slider, 1.0))
  }

  /// Shows pause button if playing, or if we were playing before scrubbing started
  var shouldShowPauseButton: Bool {
    isPlaying || ((isScrubbing || isFinishingScrub) && playbackWasActiveBeforeScrub)
  }

  // MARK: - Initialization

  init(url: URL) {
    self.url = url
  }

  // MARK: - Video Loading

  func loadVideo() async {
    do {
      try await player.load(url: url)
    } catch {
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

  func startScrubbing() {
    // Only modify state if we aren't already in a scrubbing lifecycle
    if !isScrubbing && !isFinishingScrub {
      isScrubbing = true
      playbackWasActiveBeforeScrub = isPlaying
      Task { await player.beginScrub() }
    }
  }

  func scrub(to time: Double) {
    Task { await player.scrub(to: time) }
  }

  func endScrubbing(at time: Double) {
    isScrubbing = false
    isFinishingScrub = true

    Task {
      await player.scrub(to: time)
      await player.endScrub(resumePlayback: playbackWasActiveBeforeScrub)
      isFinishingScrub = false
    }
  }

  // MARK: - Cleanup

  nonisolated func cleanupSync() {
    player.cancelAllTasks()
    player.closeSync()  // Synchronously release decoder, audio, and renderer cache
  }

  nonisolated deinit {
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
