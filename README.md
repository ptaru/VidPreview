# VidPreview

A high-performance QuickLook extension for macOS that enables native video preview in Finder for formats not natively supported by macOS.

![Platform](https://img.shields.io/badge/platform-macOS%2015.6%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Overview

VidPreview brings full video playback capabilities to macOS QuickLook (press **Space** in Finder) for MKV, WebM, AVI, and Ogg video files. It seamlessly integrates with Finder to provide a native-like experience for playing videos and viewing thumbnails.

## Features

- **QuickLook Integration**: Preview videos directly in Finder with spacebar
- **Broad Container Support**: MKV, WebM, AVI, Ogg/Theora, and more
- **Wide Codec Support**: H.264, H.265/HEVC, VP8, VP9, AV1, and more
- **HDR Support**: Comprehensive support including HDR10, HLG, and Dolby Vision
- **Track selection**: Switch audio and subtitle tracks easily
- **Thumbnail Support**: Generates thumbnails for unsupported video formats in Finder

## VidCore

VidPreview is powered by [VidCore](https://github.com/ptaru/VidCore), a Swift-based video playback framework built on FFmpeg and VideoToolbox.

## Requirements

- macOS 15.6 or later

## Installation

### Homebrew

```bash
brew install ptaru/tap/vidpreview
```

### Building from Source

1. **Clone the repository**:
   ```bash
   git clone https://github.com/ptaru/VidPreview.git
   cd VidPreview
   ```

2. **Build VidCore**:
   VidPreview is powered by [VidCore](https://github.com/ptaru/VidCore). You must build it before the main application, following the instructions in its README.

3. **Embed VidCore framework**:
   Ensure `VidCore.framework` is properly embedded in the VidPreview targets:
   - For **VidPreview**, **VidPreviewQuickLook**, and **VidPreviewThumbnail** targets:
     - Go to **General** → **Frameworks, Libraries, and Embedded Content**
     - Ensure `VidCore.framework` is added and set to **Embed & Sign**

4. **Build the project**:
   - Select **VidPreview** scheme
   - Build (⌘B) and Run (⌘R)

5. **Enable the QuickLook extension**:
   After building and running once:
   - Go to **System Settings** → **Privacy & Security** → **Extensions** → **Quick Look**
   - Enable **VidPreview**

## Usage

1. **Enable the extension** in System Settings (see step 4 above)
2. Navigate to a video file in Finder (MKV, WebM, AVI, or Ogg)
3. Press **Space** to open QuickLook
4. Video will play automatically with full playback controls

### Supported Codecs

**Video**: H.264, H.265/HEVC, VP8, VP9, AV1, MPEG-4, Theora, and more

**Audio**: AAC, MP3, Opus, Vorbis, FLAC, PCM

## Troubleshooting

### Extension not showing up

1. Rebuild and run the app at least once
2. Check **System Settings** → **Privacy & Security** → **Extensions** → **Quick Look**
3. Enable **VidPreview**
4. Restart Finder: `killall Finder`

## Acknowledgments

- **FFmpeg** - Video demuxing and decoding support

---

Made by Tarun
