//
//  PreviewRegistry.swift
//  VidPreviewQuickLook
//
//  Shared registry to track all active preview instances for coordinating playback.
//  When Quick Look shows multiple files, this ensures only the active preview plays.
//

import Foundation

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
    }

    func unregister(_ controller: PreviewViewController) {
        let id = ObjectIdentifier(controller)
        previews.removeValue(forKey: id)
        cleanupStaleRefs()
    }

    // MARK: - Playback Coordination

    /// Pauses all previews except the specified one
    func pauseAllExcept(_ active: PreviewViewController) {
        cleanupStaleRefs()

        for (_, ref) in previews {
            guard let controller = ref.controller, controller !== active else { continue }

            if controller.viewModel?.isPlaying == true {
                controller.viewModel?.pause()
            }
        }
    }

    // MARK: - Private

    /// Removes any weak refs that have become nil (handles arbitrary deallocation)
    private func cleanupStaleRefs() {
        previews = previews.filter { $0.value.controller != nil }
    }

    /// Wrapper to hold weak reference to PreviewViewController
    private class WeakPreviewRef {
        weak var controller: PreviewViewController?
        init(_ controller: PreviewViewController) {
            self.controller = controller
        }
    }
}
