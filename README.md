
<img height="128" alt="VidPreview" src="https://github.com/user-attachments/assets/3c574936-65d1-40e7-9fad-77454cf28cb7" />


VidPreview high-performance Quick Look extension for macOS that enables video previews in Finder for formats not natively supported by macOS.

![Platform](https://img.shields.io/badge/platform-macOS%2015.6%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

<img width="1920" height="1176" alt="screenshot" src="https://github.com/user-attachments/assets/955c1298-b57f-42af-80a4-cbe3d2737746" />

## Overview

VidPreview brings full video playback capabilities to macOS QuickLook (press **Space** in Finder) for any file that libavcodec can decode. It seamlessly integrates with Finder to generate thumbnails for all your videos and provide a native-like experience for playing them.

## Features

- Uses libavformat for demuxing, supporting MKV, WebM, AVI, Ogg/Theora, and more
- Hardware video decoding whenever possible, falling back to libavcodec to play anything under the sun
- Pixel-perfect colour reproduction, identical to QuickTime
- HDR support including system-level Dolby Vision (Profiles 5 and 8)
- Audio track selection with display of comprehensive information
- Support for bitmap and text subtitles, including positioning and advanced substation alpha effects
- Generates thumbnails for unsupported video formats in Finder

## VidCore

VidPreview is powered by [VidCore](https://github.com/ptaru/VidCore.framework), a Swift-based video playback framework built on FFmpeg and VideoToolbox.

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
   VidPreview is powered by [VidCore](https://github.com/ptaru/VidCore.framework). You must build it before the main application, following the instructions in its README.

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

### Audio/video formats
- Hardware decoding for all formats supported by VideoToolbox and AudioToolbox
- Software decoding for all formats supported by libavcodec (dav1d used instead of libaom for AV1)


### Subtitle formats
- Advanced Rendering: ASS/SSA (Advanced Substation Alpha) via libass
- Text: SRT (SubRip)
- Bitmap/Image-based: PGS (Blu-ray) and VobSub (DVD)

### Container Formats
- Internally supports all standard libavformat demuxers, but the Quick Look and thumbnail extensions register themselves for mp4, m4v, mov, mkv, avi, webm, flv, wmv, asf, ogv, ogm, ogg, ts, mts, m2ts, vob, vro, divx, xvid, 3gp, 3g2, dv, mxf, gxf, rm, rmvb, wtv, xesc, mpg, mpeg, m2v, tod, mod, nsv, nuv, rec, dvr-ms, dvdmedia, flc, and bdav

## Troubleshooting

### Extension not showing up

1. Rebuild and run the app at least once
2. Check **System Settings** → **Privacy & Security** → **Extensions** → **Quick Look**
3. Enable **VidPreview**
4. Restart Finder: `killall Finder`

### Video not playing

You can test video playback by dragging any video file into the VidPreview help window (the one you get if you launch the app directly). Please submit issues here for any bugs or issues.

## Acknowledgments

- **FFmpeg** - libavformat and libavcodec

---

Made by Tarun
