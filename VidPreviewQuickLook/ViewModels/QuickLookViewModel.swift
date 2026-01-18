//
//  QuickLookViewModel.swift
//  VidPreviewQuickLook
//

import Foundation
import Observation
import SwiftUI
import VidCore
import Quartz
import os

private let logger = Logger(subsystem: "com.vidpreview.quicklook", category: "viewmodel")

@Observable
@MainActor
class QuickLookViewModel {
    // MARK: - Player
    
    let player = VideoPlayer(frameBufferSize: 3, packetQueueSize: 10)
    private let url: URL
    
    // MARK: - UI State (QuickLook-specific)
    
    var isScrubbing: Bool = false
    private(set) var playbackWasActiveBeforeScrub: Bool = false
    
    // MARK: - Passthrough Properties
    
    var playbackState: PlaybackState { player.state }
    var currentFrame: VideoFrame? { player.currentFrame }
    var currentTime: Double {
        get { player.currentTime }
        set { /* Only settable during scrubbing for UI purposes */ }
    }
    var duration: Double { player.duration }
    var videoInfo: VideoInfo? { player.videoInfo }
    var renderingEngine: RenderingEngine? { player.renderingEngine }
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
        isPlaying || (isScrubbing && playbackWasActiveBeforeScrub)
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
            logger.info("[QuickLookViewModel] Video loaded: \(self.videoInfo?.width ?? 0)x\(self.videoInfo?.height ?? 0)")
        } catch {
            logger.error("[QuickLookViewModel] Failed to load video: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Playback Control
    
    func play() {
        player.play()
    }
    
    func pause() {
        player.pause()
    }
    
    func togglePlayPause() {
        player.togglePlayPause()
    }
    
    // MARK: - Scrubbing
    
    private var scrubTask: Task<Void, Never>?
    
    func startScrubbing() {
        // Only modify state if we aren't already scrubbing
        if !isScrubbing {
            isScrubbing = true
            playbackWasActiveBeforeScrub = isPlaying
            if isPlaying {
                pause()
            }
        }
    }
    
    func scrub(to time: Double) {
        // Cancel any pending inaccurate seek
        scrubTask?.cancel()
        
        scrubTask = Task {
            // Debounce slightly to avoid flooding the decoder during rapid dragging
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            if Task.isCancelled { return }
            
            await player.seek(to: time, accurate: false)
        }
    }
    
    func endScrubbing(at time: Double) {
        scrubTask?.cancel()
        isScrubbing = false
        
        Task {
            // Perform final accurate seek
            await player.seek(to: time, accurate: true)
            
            if playbackWasActiveBeforeScrub {
                play()
            }
        }
    }
    
    // MARK: - Seeking
    
    func seek(to seconds: Double, accurate: Bool = true) async {
        await player.seek(to: seconds, accurate: accurate)
    }
    
    // MARK: - Cleanup
    
    nonisolated func cleanupSync() {
        player.closeSync()  // Synchronously release decoder, audio, and renderer cache
    }
    
    nonisolated deinit {
        print("[QuickLookViewModel] DEINIT - deallocating")
        cleanupSync()
    }
}
