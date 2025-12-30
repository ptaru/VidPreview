//
//  PreviewRegistry.swift
//  VidPreviewQuickLook
//
//  Shared registry to track all active preview instances for coordinating playback.
//  When Quick Look shows multiple files, this ensures only the active preview plays.
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.vidpreview.quicklook", category: "focus")

/// Shared registry to track all active preview instances for coordinating playback
@MainActor
final class PreviewRegistry {
    static let shared = PreviewRegistry()
    
    private var previews: [ObjectIdentifier: WeakPreviewRef] = [:]
    
    private init() {}
    
    // MARK: - Registration
    
    func register(_ controller: PreviewViewController) {
        let id = ObjectIdentifier(controller)
        previews[id] = WeakPreviewRef(controller)
        logger.debug("[PreviewRegistry] Registered preview - count: \(self.previews.count, privacy: .public)")
    }
    
    func unregister(_ controller: PreviewViewController) {
        let id = ObjectIdentifier(controller)
        previews.removeValue(forKey: id)
        cleanupStaleRefs()
        logger.debug("[PreviewRegistry] Unregistered preview - count: \(self.previews.count, privacy: .public)")
    }
    
    // MARK: - Playback Coordination
    
    /// Pauses all previews except the specified one
    func pauseAllExcept(_ active: PreviewViewController) {
        cleanupStaleRefs()
        
        for (_, ref) in previews {
            guard let controller = ref.controller, controller !== active else { continue }
            
            if controller.viewModel?.isPlaying == true {
                let fileName = controller.currentFileURL?.lastPathComponent ?? "unknown"
                logger.debug("[PreviewRegistry] Pausing inactive preview: \(fileName, privacy: .public)")
                controller.viewModel?.pause()
            }
        }
    }
    
    // MARK: - Private
    
    /// Removes any weak refs that have become nil (handles arbitrary deallocation)
    private func cleanupStaleRefs() {
        let beforeCount = previews.count
        previews = previews.filter { $0.value.controller != nil }
        let removed = beforeCount - previews.count
        if removed > 0 {
            logger.debug("[PreviewRegistry] Cleaned up \(removed, privacy: .public) stale preview refs")
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
