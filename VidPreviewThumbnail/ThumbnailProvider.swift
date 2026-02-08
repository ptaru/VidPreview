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

    // Run thumbnail generation in a Task to support async/await
    Task {
      do {
        let decoder = try MediaDecoder(url: fileURL)
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
        // extractCoverImage is likely async now
        if let coverData = await decoder.extractCoverImage(),
          let image = NSImage(data: coverData)
        {
          // Use the cover image's own dimensions
          let coverWidth = image.size.width
          let coverHeight = image.size.height
          let coverTargetSize = Self.calculateThumbnailSize(
            videoWidth: coverWidth,
            videoHeight: coverHeight,
            maxSize: maxSize
          )

          let reply = QLThumbnailReply(contextSize: coverTargetSize) { () -> Bool in
            Self.drawImage(image, in: coverTargetSize)
          }
          handler(reply, nil)
          decoder.close()
          return
        }

        var extractedCGImage: CGImage?

        // Try multiple seek positions as fallback
        let seekPositions: [Double] = [
          videoInfo.duration * 0.1,  // 10% - skip intros
          5.0,  // 5 seconds - fallback
          0.0,  // Beginning - last resort
        ]

        for seekTime in seekPositions {
          // Seek to target position
          do {
            _ = try await decoder.seek(to: max(0, seekTime))
          } catch {
            continue
          }

          // Decode packets until we get a video frame
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
            
            // Decode
            let frames = await decoder.decodePacket(packet)
            
            for frame in frames {
              if case .video(let videoFrame) = frame {
                // Use System Renderer logic to convert to CGImage
                extractedCGImage = AVSystemVideoRenderer.createCGImage(from: videoFrame)
                break
              }
            }

            if extractedCGImage != nil {
              break
            }

            packetCount += 1
          }

          if extractedCGImage != nil {
            break
          }
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
  case noFrameExtracted

  var errorDescription: String? {
    switch self {
    case .noFrameExtracted:
      return "Failed to extract video frame"
    }
  }
}
