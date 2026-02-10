//
//  QLVolumeControl.swift
//  VidPreviewQuickLook
//

import SwiftUI
import VidCore

struct QLVolumeControl: View {
    @Bindable var viewModel: QuickLookViewModel

    var body: some View {
        HStack(spacing: 8) {
            GlassSlider(
                value: $viewModel.volumeSlider,
                range: 0...1,
                tintColor: Color(red: 0, green: 0.5, blue: 1.0)
            )
            .frame(width: 100)

            Button(action: {
                viewModel.toggleMute()
            }) {
                Image(systemName: volumeIcon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(8)
    }

    private var volumeIcon: String {
        if viewModel.volumeSlider == 0 {
            return "speaker.slash.fill"
        } else if viewModel.volumeSlider < 0.33 {
            return "speaker.wave.1.fill"
        } else if viewModel.volumeSlider < 0.67 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
}
