//
//  BookmarkManager.swift
//  VidPreview
//

import Foundation
import os

class BookmarkManager {
    static let shared = BookmarkManager()
    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.vidpreview", category: "BookmarkManager")

    private init() {}

    func saveBookmark(for url: URL) {
        do {
            // Start accessing to ensure we have permission to create the bookmark
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            // Use the absolute string or path as key.
            // Since we want to look it up by the restored URL's path/string.
            defaults.set(bookmarkData, forKey: url.path)
            logger.info("Saved bookmark for: \(url.lastPathComponent)")
        } catch {
            logger.error(
                "Failed to save bookmark for \(url.lastPathComponent): \(error.localizedDescription)"
            )
        }
    }

    func resolveBookmark(for url: URL) -> URL? {
        guard let bookmarkData = defaults.data(forKey: url.path) else {
            logger.warning("No bookmark found for: \(url.lastPathComponent)")
            return nil
        }

        var isStale = false
        do {
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                logger.info("Bookmark is stale for: \(url.lastPathComponent), attempting to renew")
                saveBookmark(for: resolvedURL)
            }

            logger.info("Resolved bookmark for: \(resolvedURL.lastPathComponent)")
            return resolvedURL
        } catch {
            logger.error(
                "Failed to resolve bookmark for \(url.lastPathComponent): \(error.localizedDescription)"
            )
            return nil
        }
    }
}
