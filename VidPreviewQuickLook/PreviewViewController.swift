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

    private var hasInitialAutoplayOccurred = false

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

    override func viewDidLayout() {
        super.viewDidLayout()

        // If we haven't autoplayed yet, check if we can now
        if !hasInitialAutoplayOccurred, let vm = viewModel, !vm.isPlaying {
            if isViewportLargeEnough() {
                logger.debug(
                    "[PreviewViewController] Viewport became large enough, starting playback")
                hasInitialAutoplayOccurred = true
                vm.play()
            }
        }
    }

    // MARK: - QLPreviewingController

    func preparePreviewOfFile(at url: URL) async throws {
        currentFileURL = url
        logger.debug(
            "[PreviewViewController] Preparing preview: \(url.lastPathComponent, privacy: .public)")

        // Reset state for new file
        hasInitialAutoplayOccurred = false

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

        await MainActor.run {
            updatePreferredContentSize()

            // Only autoplay if the viewport is large enough (i.e. not the Finder sidebar)
            if isViewportLargeEnough() {
                hasInitialAutoplayOccurred = true
                vm.play()
            } else {
                logger.debug(
                    "[PreviewViewController] Viewport too small (\(self.view.bounds.width)x\(self.view.bounds.height)), deferring playback"
                )
            }
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

        // Only resume if we should be playing AND the user hasn't manually paused
        if let vm = viewModel, !vm.isPlaying, !vm.userManuallyPaused {
            if isViewportLargeEnough() {
                logger.debug(
                    "[PreviewViewController] Resuming playback: \(self.currentFileURL?.lastPathComponent ?? "unknown", privacy: .public)"
                )
                vm.play()
            } else {
                logger.debug("[PreviewViewController] Skipping resume - viewport too small")
            }
        }
    }

    private func performEarlyCleanup() {
        guard !hasCleanedUp else { return }
        hasCleanedUp = true

        logger.debug(
            "[PreviewViewController] Early cleanup: \(self.currentFileURL?.lastPathComponent ?? "unknown", privacy: .public)"
        )
        PreviewRegistry.shared.unregister(self)
        viewModel?.pause()
    }

    // MARK: - Private Helpers

    private func calculatePreferredSize() -> NSSize? {
        guard let info = viewModel?.videoInfo else { return nil }

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

        return NSSize(width: width, height: height)
    }

    private func updatePreferredContentSize() {
        guard let size = calculatePreferredSize() else { return }
        preferredContentSize = size
    }

    private func isViewportLargeEnough() -> Bool {
        // If we haven't calculated a preferred size yet, assume we can't play safely
        guard let preferred = calculatePreferredSize() else { return false }

        let currentSize = view.bounds.size

        // If current size is significantly smaller than preferred size, likely sidebar
        // We use a generous tolerance because window chrome might affect exact matches,
        // but the sidebar is usually MUCH smaller than a 1080p/720p preferred size.
        // Or, simply put: if the current view is very small (< 300px width?), likely sidebar.
        // But the user asked for logic comparing to preferredContentSize.

        // Let's use 80% of preferred dimensions as a threshold?
        // Or better: if either dimension is < 50% of preferred, it's likely a thumbnail view.
        // Actually, Finder sidebar width is usually restricted.

        let minimumWidthRatio = 0.8
        let minimumHeightRatio = 0.8

        // Case: video is small (e.g. 200x200), sidebar might be 200x200 too.
        // But usually preferred size is the full video size (constrained to 1280x720).

        let isWidthOk = currentSize.width >= (preferred.width * minimumWidthRatio)
        let isHeightOk = currentSize.height >= (preferred.height * minimumHeightRatio)

        return isWidthOk && isHeightOk
    }
}
