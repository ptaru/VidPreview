//
//  PreviewViewController.swift
//  VidPreviewQuickLook
//
//  QuickLook Preview Extension with full video playback
//  Uses VidCore framework for decoding and rendering
//

import Cocoa
import Quartz
import SwiftUI
import CoreVideo
import Metal
import MetalKit
import CoreImage
import VidCore
import os.log

private let focusLogger = Logger(subsystem: "com.vidpreview.quicklook", category: "focus")

/// Shared registry to track all active preview instances for coordinating playback
@MainActor
final class PreviewRegistry {
    static let shared = PreviewRegistry()
    
    private var previews: [ObjectIdentifier: WeakPreviewRef] = [:]
    
    private init() {}
    
    func register(_ controller: PreviewViewController) {
        let id = ObjectIdentifier(controller)
        previews[id] = WeakPreviewRef(controller)
        focusLogger.info("Registered preview - count: \(self.previews.count, privacy: .public)")
    }
    
    func unregister(_ controller: PreviewViewController) {
        let id = ObjectIdentifier(controller)
        previews.removeValue(forKey: id)
        // Clean up any nil refs
        previews = previews.filter { $0.value.controller != nil }
        focusLogger.info("Unregistered preview - count: \(self.previews.count, privacy: .public)")
    }
    
    /// Pauses all previews except the specified one
    func pauseAllExcept(_ active: PreviewViewController) {
        let activeFileName = active.currentFileURL?.lastPathComponent ?? "unknown"
        
        // Proactively clean up any nil weak refs (handles arbitrary deallocation)
        let beforeCount = previews.count
        previews = previews.filter { $0.value.controller != nil }
        let afterCount = previews.count
        if beforeCount != afterCount {
            focusLogger.info("Cleaned up \(beforeCount - afterCount, privacy: .public) stale preview refs")
        }
        
        focusLogger.info("pauseAllExcept called - active: \(activeFileName, privacy: .public), registered: \(self.previews.count, privacy: .public)")
        
        for (_, ref) in previews {
            guard let controller = ref.controller else { continue }
            guard controller !== active else { continue }
            
            let fileName = controller.currentFileURL?.lastPathComponent ?? "unknown"
            let isPlaying = controller.viewModel?.isPlaying ?? false
            if isPlaying {
                focusLogger.info("Pausing inactive preview: \(fileName, privacy: .public)")
                controller.viewModel?.pause()
            }
        }
    }
    
    /// Wrapper to hold weak reference to PreviewViewController
    private class WeakPreviewRef {
        weak var controller: PreviewViewController?
        init(_ controller: PreviewViewController) {
            self.controller = controller
        }
    }
}

class PreviewViewController: NSViewController, QLPreviewingController {
    
    private var hostingView: NSHostingView<QuickLookPlayerView>?
    fileprivate(set) var viewModel: QuickLookViewModel?
    private var occlusionObserver: NSObjectProtocol?
    fileprivate(set) var currentFileURL: URL?
    private var hasCleanedUp = false
    
    override var nibName: NSNib.Name? {
        return nil
    }
    
    override func loadView() {
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.cgColor
        self.view = containerView
    }
    
    deinit {
        if let observer = occlusionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        // Note: Cannot call MainActor-isolated unregister from deinit,
        // but weak refs in registry will become nil automatically
        viewModel?.cleanupSync()
    }
    
    /// Early cleanup when we detect the preview is being dismissed
    private func performEarlyCleanup() {
        guard !hasCleanedUp else { return }
        hasCleanedUp = true
        
        let fileName = currentFileURL?.lastPathComponent ?? "unknown"
        focusLogger.info("Performing early cleanup for: \(fileName, privacy: .public)")
        
        PreviewRegistry.shared.unregister(self)
        viewModel?.pause()
        // Don't call cleanupSync here - let deinit handle full cleanup
        // Just pause to stop resource usage immediately
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        PreviewRegistry.shared.register(self)
        setupOcclusionObserver()
    }
    
    private func setupOcclusionObserver() {
        guard let window = view.window else {
            focusLogger.warning("No window available for occlusion observation - file: \(self.currentFileURL?.lastPathComponent ?? "unknown", privacy: .public)")
            return
        }
        
        // Remove any existing observer
        if let existing = occlusionObserver {
            NotificationCenter.default.removeObserver(existing)
        }
        
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            let fileName = self.currentFileURL?.lastPathComponent ?? "unknown"
            let isVisible = window.occlusionState.contains(.visible)
            let isKeyWindow = window.isKeyWindow
            
            focusLogger.info("""
                Occlusion state changed - \
                file: \(fileName, privacy: .public), \
                visible: \(isVisible, privacy: .public), \
                keyWindow: \(isKeyWindow, privacy: .public)
                """)
            
            // When this preview becomes visible, pause all others and ensure we're playing
            // Use isVisible only - keyWindow might not be reliable in Quick Look's hosted environment
            if isVisible {
                // Small delay to ensure any new preview has finished registering
                DispatchQueue.main.async {
                    PreviewRegistry.shared.pauseAllExcept(self)
                    if let vm = self.viewModel, !vm.isPlaying {
                        focusLogger.info("Resuming playback for active preview: \(fileName, privacy: .public)")
                        vm.play()
                    }
                }
            } else {
                // Visibility became false - early cleanup
                focusLogger.info("Preview became not visible: \(fileName, privacy: .public)")
                self.performEarlyCleanup()
            }
        }
        
        // Log initial state and pause others if we're the visible preview
        let fileName = currentFileURL?.lastPathComponent ?? "unknown"
        let isVisible = window.occlusionState.contains(.visible)
        let isKeyWindow = window.isKeyWindow
        focusLogger.info("""
            Occlusion observer setup - \
            file: \(fileName, privacy: .public), \
            visible: \(isVisible, privacy: .public), \
            keyWindow: \(isKeyWindow, privacy: .public)
            """)
        
        // IMPORTANT: When a new preview is set up and visible, pause all others immediately
        // This handles the case where Quick Look doesn't send occlusion notifications to old previews
        if isVisible {
            focusLogger.info("New preview is visible on setup, pausing others: \(fileName, privacy: .public)")
            PreviewRegistry.shared.pauseAllExcept(self)
        }
    }

    func preparePreviewOfFile(at url: URL) async throws {
        self.currentFileURL = url
        focusLogger.info("Preparing preview for file: \(url.lastPathComponent, privacy: .public)")
        
        let vm = QuickLookViewModel(url: url)
        self.viewModel = vm
        
        await MainActor.run {
            let playerView = QuickLookPlayerView(viewModel: vm)
            let hosting = NSHostingView(rootView: playerView)
            hosting.translatesAutoresizingMaskIntoConstraints = false
            hosting.wantsLayer = true
            hosting.layer?.backgroundColor = NSColor.black.cgColor
            self.view.addSubview(hosting)
            
            NSLayoutConstraint.activate([
                hosting.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                hosting.topAnchor.constraint(equalTo: self.view.topAnchor),
                hosting.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            ])
            
            self.hostingView = hosting
        }
        
        await vm.loadVideo()
        vm.play()
        
        await MainActor.run {
            if let info = vm.videoInfo {
                let maxWidth: CGFloat = 1280
                let maxHeight: CGFloat = 720
                
                var width = CGFloat(info.width)
                var height = CGFloat(info.height)
                
                if width > maxWidth {
                    let scale = maxWidth / width
                    width = maxWidth
                    height *= scale
                }
                if height > maxHeight {
                    let scale = maxHeight / height
                    height = maxHeight
                    width *= scale
                }
                
                self.preferredContentSize = NSSize(width: width, height: height)
            }
        }
    }
}
