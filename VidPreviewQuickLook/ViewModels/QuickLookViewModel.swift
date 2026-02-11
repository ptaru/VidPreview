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

@Observable
@MainActor
class QuickLookViewModel {
    // MARK: - Player

    let player = MediaPlayer(buffers: .auto)
    private let url: URL

    // MARK: - UI State (QuickLook-specific)

    var isScrubbing: Bool = false
    private(set) var userManuallyPaused: Bool = false
    private var scrubbingTask: Task<Void, Never>?
    private var scrubFlushTask: Task<Void, Never>?
    private var pendingScrubTime: Double?
    private var lastScrubInputTime: Double?
    private var lastScrubInputTimestamp: TimeInterval?
    private var lastScrubDispatchTimestamp: TimeInterval?

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

    // MARK: - Initialization

    init(url: URL) {
        self.url = url
    }

    // MARK: - Video Loading

    func loadVideo() async {
        do {
            try await player.load(url: url)
        } catch {
            print("QuickLookViewModel: Failed to load video: \(error.localizedDescription)")
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

    func beginScrub() {
        guard !isScrubbing else { return }
        isScrubbing = true
        resetScrubRateLimiterState()
        let previous = scrubbingTask
        scrubbingTask = Task { @MainActor in
            _ = await previous?.result
            await player.beginScrub()
        }
    }

    func scrub(to time: Double) {
        let now = Date.timeIntervalSinceReferenceDate
        let velocity = scrubVelocity(for: time, at: now)
        let minInterval = minimumScrubDispatchInterval(for: velocity)

        pendingScrubTime = time
        lastScrubInputTime = time
        lastScrubInputTimestamp = now

        let elapsedSinceLastDispatch = lastScrubDispatchTimestamp.map { now - $0 } ?? .infinity
        if elapsedSinceLastDispatch >= minInterval {
            flushPendingScrub(at: now)
        } else {
            schedulePendingScrubFlush(after: minInterval - elapsedSinceLastDispatch)
        }
    }

    func endScrub() {
        scrubFlushTask?.cancel()
        flushPendingScrub(at: Date.timeIntervalSinceReferenceDate)

        let previous = scrubbingTask
        scrubbingTask = Task { @MainActor in
            _ = await previous?.result
            await player.endScrub()
            isScrubbing = false
            resetScrubRateLimiterState()
        }
    }

    private func resetScrubRateLimiterState() {
        scrubFlushTask?.cancel()
        scrubFlushTask = nil
        pendingScrubTime = nil
        lastScrubInputTime = nil
        lastScrubInputTimestamp = nil
        lastScrubDispatchTimestamp = nil
    }

    private func scrubVelocity(for targetTime: Double, at timestamp: TimeInterval) -> Double {
        guard let previousTime = lastScrubInputTime,
              let previousTimestamp = lastScrubInputTimestamp else {
            return 0
        }

        let deltaTimestamp = timestamp - previousTimestamp
        guard deltaTimestamp > 0.0005 else {
            return .infinity
        }

        return abs(targetTime - previousTime) / deltaTimestamp
    }

    private func minimumScrubDispatchInterval(for velocity: Double) -> TimeInterval {
        if velocity <= 1.25 { return 0 }
        if velocity <= 5 { return 1.0 / 120.0 }
        if velocity <= 20 { return 1.0 / 60.0 }
        if velocity <= 60 { return 1.0 / 30.0 }
        return 1.0 / 15.0
    }

    private func flushPendingScrub(at timestamp: TimeInterval) {
        guard let target = pendingScrubTime else { return }

        pendingScrubTime = nil
        scrubFlushTask?.cancel()
        scrubFlushTask = nil
        lastScrubDispatchTimestamp = timestamp

        let previous = scrubbingTask
        scrubbingTask = Task { @MainActor in
            _ = await previous?.result
            await player.scrub(to: target)
        }
    }

    private func schedulePendingScrubFlush(after delay: TimeInterval) {
        scrubFlushTask?.cancel()

        guard delay > 0 else {
            flushPendingScrub(at: Date.timeIntervalSinceReferenceDate)
            return
        }

        scrubFlushTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            flushPendingScrub(at: Date.timeIntervalSinceReferenceDate)
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
