//
//  GlassSlider.swift
//  VidPreviewQuickLook
//
//  Fancy glass slider component
//

import SwiftUI

private enum GlassSliderConstants {
    static let thumbSize: CGFloat = 20
    static let hoverThumbSize: CGFloat = 14
    static let idleThumbSize: CGFloat = 8
    static let trackHeight: CGFloat = 4


    static let hitAreaHeight: CGFloat = 28
}

/// A standalone premium slider with a 3D glass refraction effect applied to its own track.
struct GlassSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var tintColor: Color = .blue
    var onChanged: ((Double) -> Void)? = nil
    var onEnded: ((Double) -> Void)? = nil
    
    @State private var thumbCenter: CGPoint = .zero
    @State private var isDragging: Bool = false
    @State private var isHovering: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // The Track & Fill - This is what will be refracted
                ZStack(alignment: .leading) {
                    // Track Groove
                    Capsule()
                        .fill(.black.opacity(0.3))
                        .frame(height: GlassSliderConstants.trackHeight)
                        .offset(y: 1)
                    
                    // Track Background
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: GlassSliderConstants.trackHeight)
                    
                    // Active Fill
                    Capsule()
                        .fill(tintColor)
                        .frame(width: calculateFillWidth(totalWidth: geometry.size.width), height: GlassSliderConstants.trackHeight)
                }
                .frame(maxWidth: .infinity)
                .frame(height: GlassSliderConstants.hitAreaHeight)
                .layerEffect(
                    ShaderLibrary.glass(
                        .float2(thumbCenter),
                        .float(GlassSliderConstants.thumbSize / 2),
                        .float(isDragging ? 1.0 : 0.0)
                    ),
                    maxSampleOffset: CGSize(width: GlassSliderConstants.thumbSize, height: GlassSliderConstants.thumbSize)
                )
                
                // Shadow Halo with Directional Gradient
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.white.opacity(0.2), .black.opacity(0.4), .black.opacity(0.4), .white.opacity(0.2)],
                            center: .center,
                            startAngle: .degrees(45), // White at bottom-right (approx 135 deg in screen space)
                            endAngle: .degrees(405)
                        ),
                        lineWidth: 2
                    )
                    .frame(width: GlassSliderConstants.thumbSize + 1, height: GlassSliderConstants.thumbSize + 1)
                    .blur(radius: 2)
                    .rotationEffect(.degrees(-45)) // Align white to bottom-right
                    .offset(x: calculateThumbOffset(totalWidth: geometry.size.width), y: 1)
                    .opacity(isDragging ? 1 : 0)
                
                // Thumb Visuals
                ZStack {
                    // White Thumb (Idle & Hover)
                    Circle()
                        .fill(.white)
                        .frame(width: isDragging ? GlassSliderConstants.thumbSize : (isHovering ? GlassSliderConstants.hoverThumbSize : GlassSliderConstants.idleThumbSize))
                        .opacity(isDragging ? 0 : 1)
                    
                    // Glass Thumb area (Active - clear area for shader)
                    Circle()
                        .fill(.clear)
                        .frame(width: GlassSliderConstants.thumbSize, height: GlassSliderConstants.thumbSize)
                        .opacity(isDragging ? 1 : 0)
                }
                .frame(width: GlassSliderConstants.thumbSize, height: GlassSliderConstants.thumbSize)
                .offset(x: calculateThumbOffset(totalWidth: geometry.size.width))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        updateValue(dragLocation: gesture.location, totalWidth: geometry.size.width)
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEnded?(value)
                    }
            )
            .onHover { isHovering = $0 }
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .onAppear { updateThumbCenter(geometry: geometry) }
            .onChange(of: value) { updateThumbCenter(geometry: geometry) }
            .onChange(of: isDragging) { updateThumbCenter(geometry: geometry) }
            .onChange(of: isHovering) { updateThumbCenter(geometry: geometry) }
        }
        .frame(height: GlassSliderConstants.hitAreaHeight)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isDragging)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isHovering)
    }
    
    private var currentThumbSize: CGFloat {
        if isDragging { return GlassSliderConstants.thumbSize }
        if isHovering { return GlassSliderConstants.hoverThumbSize }
        return GlassSliderConstants.idleThumbSize
    }
    
    private func updateThumbCenter(geometry: GeometryProxy) {
        let x = calculateThumbOffset(totalWidth: geometry.size.width) + (GlassSliderConstants.thumbSize / 2)
        let y = geometry.size.height / 2
        
        self.thumbCenter = CGPoint(x: x, y: y)
    }
    
    private func calculateFillWidth(totalWidth: CGFloat) -> CGFloat {
        let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return totalWidth * CGFloat(normalizedValue)
    }
    
    private func calculateThumbOffset(totalWidth: CGFloat) -> CGFloat {
        let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        let rawX = totalWidth * CGFloat(normalizedValue)
        
        let visualThumbSize = isDragging ? GlassSliderConstants.thumbSize : (isHovering ? GlassSliderConstants.hoverThumbSize : GlassSliderConstants.idleThumbSize)
        let halfVisual = visualThumbSize / 2
        
        let clampedX = min(max(halfVisual, rawX), totalWidth - halfVisual)
        
        return clampedX - (GlassSliderConstants.thumbSize / 2)
    }
    
    private func updateValue(dragLocation: CGPoint, totalWidth: CGFloat) {
        let x = min(max(0, dragLocation.x), totalWidth)
        let percent = Double(x / totalWidth)
        let newValue = range.lowerBound + (percent * (range.upperBound - range.lowerBound))
        self.value = newValue
        onChanged?(newValue)
    }
}
