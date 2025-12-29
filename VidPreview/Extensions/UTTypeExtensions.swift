//
//  UTTypeExtensions.swift
//  VidPreview
//
//  UTType extensions for video formats
//

import UniformTypeIdentifiers

extension UTType {
    static let webm = UTType(importedAs: "org.webmproject.webm")
    static let mkv = UTType(importedAs: "org.matroska.mkv")
    static let ogv = UTType(importedAs: "org.xiph.ogg-video")
}
