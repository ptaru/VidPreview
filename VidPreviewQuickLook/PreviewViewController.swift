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

class PreviewViewController: NSViewController, QLPreviewingController {
    
    private var hostingView: NSHostingView<QuickLookPlayerView>?
    private var viewModel: QuickLookViewModel?
    
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
        viewModel?.cleanupSync()
    }

    func preparePreviewOfFile(at url: URL) async throws {
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
