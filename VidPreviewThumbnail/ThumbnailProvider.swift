//
//  ThumbnailProvider.swift
//  VidPreviewThumbnail
//
//  QuickLook Thumbnail Extension for video files.
//  Uses VidCore framework to extract embedded cover images or video frames.
//

import AppKit
import QuickLookThumbnailing
import VidCore

class ThumbnailProvider: QLThumbnailProvider {

    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        let fileURL = request.fileURL
        let maxSize = request.maximumSize

        // Run thumbnail generation on a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let decoder = try VideoDecoder(url: fileURL)
                let videoInfo = decoder.videoInfo

                // Calculate the target size maintaining aspect ratio
                let videoWidth = CGFloat(videoInfo.width)
                let videoHeight = CGFloat(videoInfo.height)
                let targetSize = Self.calculateThumbnailSize(
                    videoWidth: videoWidth,
                    videoHeight: videoHeight,
                    maxSize: maxSize
                )

                // Try embedded cover image first (common in MKV files)
                if let coverData = decoder.extractCoverImage(),
                    let image = NSImage(data: coverData)
                {
                    let reply = QLThumbnailReply(contextSize: targetSize) { () -> Bool in
                        Self.drawImage(image, in: targetSize)
                    }
                    handler(reply, nil)
                    decoder.close()
                    return
                }

                // Use a semaphore to bridge async/sync
                let semaphore = DispatchSemaphore(value: 0)
                var extractedCGImage: CGImage?
                var extractionError: Error?

                Task {
                    // Initialize rendering engine for GPU-accelerated YUV conversion
                    guard let renderingEngine = RenderingEngine() else {
                        extractionError = ThumbnailError.renderingEngineInitFailed
                        semaphore.signal()
                        return
                    }

                    // Try multiple seek positions as fallback
                    // Some files may have issues seeking to certain positions
                    let seekPositions: [Double] = [
                        videoInfo.duration * 0.1,  // 10% - skip intros
                        5.0,  // 5 seconds - fallback
                        0.0,  // Beginning - last resort
                    ]

                    for seekTime in seekPositions {
                        // Seek to target position (use keyframe seek for speed)
                        do {
                            try await decoder.seek(to: max(0, seekTime), accurate: false)
                        } catch {
                            // Seek failed, try next position
                            continue
                        }

                        // Decode packets until we get a video frame
                        // Hardware decoders may need many packets before producing output
                        var packetCount = 0
                        let maxPackets = 200

                        while packetCount < maxPackets {
                            guard let packet = await decoder.demuxNextPacket() else {
                                break
                            }

                            // Skip non-video packets quickly
                            guard packet.isVideo else {
                                packetCount += 1
                                continue
                            }

                            let frames = await decoder.decodePacket(packet)
                            for frame in frames {
                                if case .video(let videoFrame) = frame {
                                    // Use VidCore's Metal-based rendering to convert to CGImage
                                    // This handles all pixel formats (I420, NV12, P010, etc.)
                                    extractedCGImage = renderingEngine.renderToCGImage(
                                        videoFrame,
                                        targetSize: targetSize
                                    )
                                    break
                                }
                            }

                            if extractedCGImage != nil {
                                break
                            }

                            packetCount += 1
                        }

                        // If we got an image, we're done
                        if extractedCGImage != nil {
                            break
                        }
                    }

                    renderingEngine.flush()
                    semaphore.signal()
                }

                // Wait for async frame extraction
                semaphore.wait()

                if let error = extractionError {
                    decoder.close()
                    throw error
                }

                guard let cgImage = extractedCGImage else {
                    decoder.close()
                    throw ThumbnailError.noFrameExtracted
                }

                let reply = QLThumbnailReply(contextSize: targetSize) { () -> Bool in
                    Self.drawCGImage(cgImage, in: targetSize)
                }

                handler(reply, nil)
                decoder.close()

            } catch {
                handler(nil, error)
            }
        }
    }

    // MARK: - Private Helpers

    private static func calculateThumbnailSize(
        videoWidth: CGFloat,
        videoHeight: CGFloat,
        maxSize: CGSize
    ) -> CGSize {
        guard videoWidth > 0, videoHeight > 0 else {
            return maxSize
        }

        let videoAspect = videoWidth / videoHeight
        let maxAspect = maxSize.width / maxSize.height

        var resultWidth: CGFloat
        var resultHeight: CGFloat

        if videoAspect > maxAspect {
            // Video is wider, constrain by width
            resultWidth = maxSize.width
            resultHeight = maxSize.width / videoAspect
        } else {
            // Video is taller, constrain by height
            resultHeight = maxSize.height
            resultWidth = maxSize.height * videoAspect
        }

        return CGSize(width: resultWidth, height: resultHeight)
    }

    private static func drawImage(_ image: NSImage, in size: CGSize) -> Bool {
        guard NSGraphicsContext.current != nil else { return false }

        let rect = CGRect(origin: .zero, size: size)
        image.draw(in: rect, from: .zero, operation: .copy, fraction: 1.0)

        return true
    }

    private static func drawCGImage(_ cgImage: CGImage, in size: CGSize) -> Bool {
        // Create NSImage from CGImage and draw it - this handles coordinate systems correctly
        let nsImage = NSImage(cgImage: cgImage, size: size)
        return drawImage(nsImage, in: size)
    }
}

// MARK: - Errors

enum ThumbnailError: Error, LocalizedError {
    case renderingEngineInitFailed
    case noFrameExtracted

    var errorDescription: String? {
        switch self {
        case .renderingEngineInitFailed:
            return "Failed to initialize Metal rendering engine"
        case .noFrameExtracted:
            return "Failed to extract video frame"
        }
    }
}
