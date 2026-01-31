//
//  QLAudioTrackSelector.swift
//  VidPreviewQuickLook
//

import SwiftUI
import VidCore

struct QLAudioTrackSelector: View {
    @Bindable var viewModel: QuickLookViewModel
    @Binding var isMenuPresented: Bool
    
    private var selectedTrack: AudioTrackInfo? {
        guard viewModel.selectedAudioTrackIndex >= 0 && viewModel.selectedAudioTrackIndex < viewModel.audioTracks.count else {
            return nil
        }
        return viewModel.audioTracks[viewModel.selectedAudioTrackIndex]
    }
    
    var body: some View {
        Button(action: { isMenuPresented.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .medium))
                if let track = selectedTrack {
                    Text(track.shortDisplayName)
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isMenuPresented, arrowEdge: .bottom) {
            AudioTrackMenu(viewModel: viewModel, isPresented: $isMenuPresented)
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
        }
    }
}

private struct AudioTrackMenu: View {
    @Bindable var viewModel: QuickLookViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Audio Tracks")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.audioTracks.enumerated()), id: \.element.id) { index, track in
                        TrackRow(
                            track: track,
                            index: index,
                            isSelected: index == viewModel.selectedAudioTrackIndex,
                            action: {
                                Task {
                                    await viewModel.selectAudioTrack(at: index)
                                }
                                isPresented = false
                            }
                        )
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding(.bottom, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

private struct TrackRow: View {
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
                    let displayTitle = track.title?.isEmpty == false ? track.title! : "Track \(index + 1)"
                    Text(displayTitle)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                    
                    // Second line: language (if known) • codec • sample rate • channels
                    HStack(spacing: 6) {
                        let codecUpper = track.codecName.uppercased()
                        let langPart = track.language?.isEmpty == false ? "\(track.language!.uppercased()) • " : ""
                        Text("\(langPart)\(codecUpper) • \(track.sampleRate / 1000) kHz • \(track.channels)ch")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        if track.isDefault {
                            Text("Default")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(3)
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
