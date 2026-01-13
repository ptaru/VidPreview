# VidPreview

A high-performance QuickLook extension for macOS that enables native video preview in Finder for formats not natively supported by macOS.

![Platform](https://img.shields.io/badge/platform-macOS%2026.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Overview

VidPreview brings full video playback capabilities to macOS QuickLook (press **Space** in Finder) for MKV, WebM, AVI, and Ogg video files. It seamlessly integrates with Finder to provide a native-like experience for playing videos and viewing thumbnails.

## Features

- **QuickLook Integration**: Preview videos directly in Finder with spacebar
- **Broad Container Support**: MKV, WebM, AVI, Ogg/Theora
- **Wide Codec Support**: H.264, H.265/HEVC, VP8, VP9, AV1, and more
- **HDR10 Support**: Correctly renders HDR content on supported displays
- **Audio Playback**: Synchronized audio support
- **Thumbnail Support**: Generates thumbnails for unsupported video formats in Finder

## VidCore

VidPreview is powered by [VidCore](https://github.com/ptaru/VidCore), a high-performance video decoding and rendering framework built on FFmpeg and Metal.

## Requirements

- macOS 26.0 or later

## Installation

### Building from Source

1. **Clone the repository including the VidCore submodule**:
   ```bash
   git clone --recursive https://github.com/ptaru/VidPreview.git
   cd VidPreview
   ```

2. **Build FFmpeg + dav1d**:
   VidPreview uses bundled static libraries for FFmpeg and dav1d. If they are missing, build them using the included script:

   ```bash
   # Install build tools
   brew install nasm meson ninja pkg-config

   # Run build script
   cd VidCore/Scripts
   ./build-ffmpeg.sh
   ```

3. **Build the project**:
   - Open `VidPreview.xcodeproj` in Xcode
   - Select **VidPreview** scheme
   - Build (⌘B) and Run (⌘R)

4. **Enable the QuickLook extension**:
   After building and running once:
   - Go to **System Settings** → **Privacy & Security** → **Extensions** → **Quick Look**
   - Enable **VidPreview**

## Usage

1. **Enable the extension** in System Settings (see step 4 above)
2. Navigate to a video file in Finder (MKV, WebM, AVI, or Ogg)
3. Press **Space** to open QuickLook
4. Video will play automatically with full playback controls

### Supported Formats

| Format | Extension | Container | Typical Codecs |
|--------|-----------|-----------|----------------|
| Matroska | `.mkv` | MKV | H.264, H.265, VP9, AV1 |
| WebM | `.webm` | WebM | VP8, VP9, AV1 |
| AVI | `.avi` | AVI | H.264, MPEG-4, DivX, Xvid |
| Ogg | `.ogg`, `.ogv` | Ogg | Theora |

### Supported Codecs

**Video**: H.264, H.265/HEVC, VP8, VP9, AV1, MPEG-4, Theora, and more

**Audio**: AAC, MP3, Opus, Vorbis, FLAC, PCM

## Troubleshooting

### Extension not showing up

1. Rebuild and run the app at least once
2. Check **System Settings** → **Privacy & Security** → **Extensions** → **Quick Look**
3. Enable **VidPreview**
4. Restart Finder: `killall Finder`

### Video not playing

1. Check that the video file is a supported format
2. View Console.app for error messages (filter by "VidPreview")

### Build errors

1. Ensure FFmpeg libraries were built: `ls VidCore/Frameworks/FFmpeg/lib`
2. If missing, run `VidCore/Scripts/build-ffmpeg.sh`
3. Clean build folder (⇧⌘K) and rebuild

## Acknowledgments

- **FFmpeg** - Video decoding and container format support
- **Metal** - GPU-accelerated rendering
- **VideoToolbox** - Hardware acceleration on Apple Silicon

---

Made by Tarun
