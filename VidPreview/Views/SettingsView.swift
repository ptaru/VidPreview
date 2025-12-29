//
//  SettingsView.swift
//  VidPreview
//
//  QuickLook Extension Settings & About View
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 24) {
            // App Icon and Title
            VStack(spacing: 12) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                
                Text("VidPreview")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("QuickLook Extension for Video Files")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            
            Divider()
                .padding(.horizontal, 40)
            
            // Instructions
            VStack(alignment: .leading, spacing: 16) {
                Text("How to Use")
                    .font(.headline)
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "1.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Select a video file in Finder")
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "2.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Press **Space** to preview with QuickLook")
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "3.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Enjoy full video playback in the preview!")
                }
            }
            .frame(maxWidth: 300, alignment: .leading)
            
            Divider()
                .padding(.horizontal, 40)
            
            // Supported Formats
            VStack(spacing: 12) {
                Text("Supported Formats")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    FormatBadge(format: "MKV")
                    FormatBadge(format: "WebM")
                    FormatBadge(format: "Ogg")
                }
            }
            
            // Footer
            Text("Made by Tarun, Powered by FFmpeg")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 16)
        }
        .frame(minWidth: 400, minHeight: 450)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct FormatBadge: View {
    let format: String
    
    var body: some View {
        Text(format)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.blue.opacity(0.1))
            .foregroundStyle(.blue)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    SettingsView()
}
