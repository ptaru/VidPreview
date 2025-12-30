//
//  PreviewViewController.swift
//  VidPreviewQuickLook
//
//  QuickLook Preview Extension with full video playback.
//  Uses VidCore framework for decoding and rendering.
//

import Cocoa
import Quartz
import SwiftUI
import VidCore
import os.log

private let logger = Logger(subsystem: "com.vidpreview.quicklook", category: "focus")

class PreviewViewController: NSViewController, QLPreviewingController {
    
    // MARK: - Properties
    
    private var hostingView: NSHostingView<QuickLookPlayerView>?
    fileprivate(set) var viewModel: QuickLookViewModel?
    fileprivate(set) var currentFileURL: URL?
    
    private var occlusionObserver: NSObjectProtocol?
    private var hasCleanedUp = false
    
    override var nibName: NSNib.Name? { nil }
    
    // MARK: - Lifecycle
    
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
        viewModel?.cleanupSync()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        PreviewRegistry.shared.register(self)
        setupOcclusionObserver()
    }
    
    // MARK: - QLPreviewingController
    
    func preparePreviewOfFile(at url: URL) async throws {
        currentFileURL = url
        logger.debug("[PreviewViewController] Preparing preview: \(url.lastPathComponent, privacy: .public)")
        
        let vm = QuickLookViewModel(url: url)
        self.viewModel = vm
        
        await MainActor.run {
            let playerView = QuickLookPlayerView(viewModel: vm)
            let hosting = NSHostingView(rootView: playerView)
            hosting.translatesAutoresizingMaskIntoConstraints = false
            hosting.wantsLayer = true
            hosting.layer?.backgroundColor = NSColor.black.cgColor
            view.addSubview(hosting)
            
            NSLayoutConstraint.activate([
                hosting.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hosting.topAnchor.constraint(equalTo: view.topAnchor),
                hosting.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            
            hostingView = hosting
        }
        
        await vm.loadVideo()
        vm.play()
        
        await MainActor.run {
            updatePreferredContentSize()
        }
    }
    
    // MARK: - Occlusion Handling
    
    private func setupOcclusionObserver() {
        guard let window = view.window else {
            logger.warning("No window available for occlusion observation")
            return
        }
        
        if let existing = occlusionObserver {
            NotificationCenter.default.removeObserver(existing)
        }
        
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.handleOcclusionChange()
        }
        
        // When a new preview is set up and visible, pause all others immediately
        if window.occlusionState.contains(.visible) {
            becameActivePreview()
        }
    }
    
    private func handleOcclusionChange() {
        guard let window = view.window else { return }
        let isVisible = window.occlusionState.contains(.visible)
        
        if isVisible {
            DispatchQueue.main.async { [weak self] in
                self?.becameActivePreview()
            }
        } else {
            performEarlyCleanup()
        }
    }
    
    private func becameActivePreview() {
        PreviewRegistry.shared.pauseAllExcept(self)
        
        if let vm = viewModel, !vm.isPlaying {
            logger.debug("[PreviewViewController] Resuming playback: \(self.currentFileURL?.lastPathComponent ?? "unknown", privacy: .public)")
            vm.play()
        }
    }
    
    private func performEarlyCleanup() {
        guard !hasCleanedUp else { return }
        hasCleanedUp = true
        
        logger.debug("[PreviewViewController] Early cleanup: \(self.currentFileURL?.lastPathComponent ?? "unknown", privacy: .public)")
        PreviewRegistry.shared.unregister(self)
        viewModel?.pause()
    }
    
    // MARK: - Private Helpers
    
    private func updatePreferredContentSize() {
        guard let info = viewModel?.videoInfo else { return }
        
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
        
        preferredContentSize = NSSize(width: width, height: height)
    }
}
