//
//  QLTrackSelector.swift
//  VidPreviewQuickLook
//

import SwiftUI
import VidCore

struct QLTrackSelector: View {
    @Bindable var viewModel: QuickLookViewModel
    @Binding var isMenuPresented: Bool

    private var selectedAudioTrack: AudioTrackInfo? {
        guard
            viewModel.selectedAudioTrackIndex >= 0
                && viewModel.selectedAudioTrackIndex < viewModel.audioTracks.count
        else {
            return nil
        }
        return viewModel.audioTracks[viewModel.selectedAudioTrackIndex]
    }

    private var selectedSubtitleTrack: SubtitleTrackInfo? {
        guard
            viewModel.selectedSubtitleTrackIndex >= 0
                && viewModel.selectedSubtitleTrackIndex < viewModel.subtitleTracks.count
        else {
            // -1 is valid for "Off", but we return nil here to indicate no track object
            return nil
        }
        return viewModel.subtitleTracks[viewModel.selectedSubtitleTrackIndex]
    }

    var body: some View {
        Button(action: { isMenuPresented.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .medium))

                // Show current state summary
                HStack(spacing: 4) {
                    if let audio = selectedAudioTrack {
                        Text(audio.shortDisplayName)
                    }

                    if let sub = selectedSubtitleTrack {
                        if selectedAudioTrack != nil {
                            Text(" ")
                                .foregroundColor(.secondary)
                        }
                        Image(systemName: "captions.bubble.fill")
                            .font(.system(size: 14, weight: .medium))
                        Text(sub.shortDisplayName)
                    }
                }
                .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isMenuPresented, arrowEdge: .bottom) {
            TrackMenu(viewModel: viewModel, isPresented: $isMenuPresented)
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
        }
    }
}

private struct TrackMenu: View {
    @Bindable var viewModel: QuickLookViewModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    // Subtitles Section (Above Audio)
                    if !viewModel.subtitleTracks.isEmpty {
                        Section(
                            header:
                                VStack(alignment: .leading, spacing: 0) {
                                    MenuSectionHeader(title: "Subtitles")
                                    Divider()
                                }
                                .background(.ultraThinMaterial)
                        ) {
                            VStack(alignment: .leading, spacing: 0) {
                                // Off Option
                                SubtitleRow(
                                    track: nil,
                                    index: -1,
                                    isSelected: viewModel.selectedSubtitleTrackIndex == -1,
                                    action: {
                                        Task { await viewModel.selectSubtitleTrack(at: -1) }
                                        isPresented = false
                                    }
                                )

                                ForEach(
                                    Array(viewModel.subtitleTracks.enumerated()), id: \.element.id
                                ) {
                                    index, track in
                                    SubtitleRow(
                                        track: track,
                                        index: index,
                                        isSelected: index == viewModel.selectedSubtitleTrackIndex,
                                        action: {
                                            Task { await viewModel.selectSubtitleTrack(at: index) }
                                            isPresented = false
                                        }
                                    )
                                }
                            }
                        }
                    }

                    // Audio Section
                    if !viewModel.audioTracks.isEmpty {
                        Section(
                            header:
                                VStack(alignment: .leading, spacing: 0) {
                                    MenuSectionHeader(title: "Audio Tracks")
                                    Divider()
                                }
                                .background(.ultraThinMaterial)
                        ) {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(viewModel.audioTracks.enumerated()), id: \.element.id)
                                {
                                    index, track in
                                    AudioTrackRow(
                                        track: track,
                                        index: index,
                                        isSelected: index == viewModel.selectedAudioTrackIndex,
                                        action: {
                                            Task { await viewModel.selectAudioTrack(at: index) }
                                            isPresented = false
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding(.bottom, 6)
    }
}

private struct MenuSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }
}

private struct AudioTrackRow: View {
    let track: AudioTrackInfo
    let index: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 2) {
                    // First line: title or track number
                    let displayTitle =
                        track.title?.isEmpty == false ? track.title! : "Track \(index + 1)"
                    Text(displayTitle)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                        .help(displayTitle)

                    // Second line: language (if known) • codec • sample rate • channels
                    HStack(spacing: 6) {
                        let codecUpper = track.codecName.uppercased()
                        let langPart =
                            track.language?.isEmpty == false
                            ? "\(track.language!.uppercased()) • " : ""
                        Text(
                            "\(langPart)\(codecUpper) • \(track.sampleRate / 1000) kHz • \(track.channels)ch"
                        )
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                        if track.isDefault {
                            DefaultBadge()
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

private struct SubtitleRow: View {
    let track: SubtitleTrackInfo?
    let index: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 2) {
                    if let track = track {
                        // Title
                        let displayTitle =
                            track.title?.isEmpty == false
                            ? track.title! : (track.language?.uppercased() ?? "Track \(index + 1)")
                        Text(displayTitle)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? .primary : .secondary)
                            .lineLimit(1)
                            .help(displayTitle)

                        // Details
                        HStack(spacing: 6) {
                            let codecUpper = track.codecName.uppercased()
                            let typeInfo = track.isBitmap ? "Bitmap" : "Text"
                            Text("\(codecUpper) • \(typeInfo)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            if track.isDefault {
                                DefaultBadge()
                            }
                        }
                    } else {
                        // Off
                        Text("Off")
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? .primary : .secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

private struct DefaultBadge: View {
    var body: some View {
        Text("Default")
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.orange)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.orange.opacity(0.15))
            .cornerRadius(3)
    }
}
