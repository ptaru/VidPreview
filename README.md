# VidPreview

A high-performance QuickLook extension for macOS that enables native video preview in Finder for formats not natively supported by macOS.

![Platform](https://img.shields.io/badge/platform-macOS%2015.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Overview

VidPreview brings full video playback capabilities to macOS QuickLook (press **Space** in Finder) for MKV, WebM, AVI, and Ogg video files. Built on the [VidCore](https://github.com/ptaru/VidCore) framework, it provides hardware-accelerated decoding via VideoToolbox, HDR10 support, and GPU-accelerated rendering via Metal.

## Features

- **QuickLook Integration**: Preview videos directly in Finder with spacebar
- **Broad Format Support**: MKV, WebM, AVI, Ogg/Theora
- **Wide Codec Support**: H.264, H.265/HEVC, VP8, VP9, AV1, and more
- **Hardware Acceleration**: Automatic VideoToolbox acceleration when available
- **HDR10 Support**: Full BT.2020 color primaries with PQ transfer function
- **Metal Rendering**: Zero-copy GPU YUV→RGB conversion
- **Audio Playback**: Synchronized audio with A/V sync correction
- **Optimized Performance**: Intelligent buffering and GPU-accelerated rendering

## Requirements

- macOS 15.0 or later
- Xcode 15.0 or later

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

4. **Build the project**:
   - Open `VidPreview.xcodeproj` in Xcode
   - Select **VidPreview** scheme
   - Build (⌘B) and Run (⌘R)

5. **Enable the QuickLook extension**:

   After building and running once:
   - Go to **System Settings** → **Privacy & Security** → **Extensions** → **Quick Look**
   - Enable **VidPreview**

## Usage

1. **Enable the extension** in System Settings (see step 5 above)
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

## Project Structure

```
VidPreview/
├── VidPreview/              # QuickLook extension host app
│   ├── VidPreviewApp.swift  # Main app entry point
│   └── Views/               # Settings view
├── VidPreviewQuickLook/     # QuickLook extension implementation
│   ├── PreviewViewController.swift
│   ├── ViewModels/
│   └── Views/
├── VidCore/                 # Core video framework
│   ├── Decoding/            # FFmpeg decoder wrapper
│   ├── Rendering/           # Metal rendering engine
│   ├── Playback/            # Video player and audio
│   ├── Buffers/             # Frame and packet buffers
│   └── SwiftUI/             # SwiftUI components
└── README.md                # This file
```

## VidCore Framework

VidPreview is built on the [VidCore](https://github.com/ptaru/VidCore) framework, a high-performance video decoding and rendering framework for macOS. VidCore can be used independently in other macOS applications for video playback needs.

See [VidCore/README.md](https://github.com/ptaru/VidCore/blob/main/README.md) for detailed API documentation.

## HDR Support

VidPreview includes full HDR10 support:

- **Color Primaries**: BT.2020 (wide color gamut)
- **Transfer Function**: PQ/SMPTE ST 2084 (HDR10)
- **Bit Depth**: 10-bit color depth
- **Output**: Linear light values for EDR displays

HDR content is automatically detected and rendered with proper color mapping on EDR-capable displays.

## Performance

VidCore includes several optimizations for efficient video playback:

- **GPU YUV Conversion**: Zero-copy rendering eliminates 20-30ms CPU overhead per frame for 4K video
- **CVPixelBufferPool**: Reduces memory fragmentation for high-resolution playback
- **Frame Reordering**: Handles multi-threaded decoders (AV1, VP9) that output frames out-of-order
- **Optimized Seeking**: Two-phase seek with keyframe optimization

## Troubleshooting

### Extension not showing up

1. Rebuild and run the app at least once
2. Check **System Settings** → **Privacy & Security** → **Extensions** → **Quick Look**
3. Enable **VidPreview**
4. Restart Finder: `killall Finder`

### Video not playing

1. Check that the video file is a supported format
2. View Console.app for error messages (filter by "VidPreview" or "VidCore")

### Build errors

1. Ensure FFmpeg libraries were built: `ls VidCore/Frameworks/FFmpeg/lib`
2. If missing, run `VidCore/Scripts/build-ffmpeg.sh`
3. Clean build folder (⇧⌘K) and rebuild

## Development

### Building for Development

```bash
# Open in Xcode
open VidPreview.xcodeproj

# Or build from command line
xcodebuild -project VidPreview.xcodeproj -scheme VidPreview -configuration Debug
```

### Running Tests

The VidCore framework includes inline documentation and examples. To test video playback:

1. Build and run the VidPreview app
2. Check the QuickLook extension in Finder with test video files

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Acknowledgments

- **FFmpeg** - Video decoding and container format support
- **Metal** - GPU-accelerated rendering
- **VideoToolbox** - Hardware acceleration on Apple Silicon

---

Made by Tarun
