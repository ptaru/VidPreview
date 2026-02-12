//
//  GlassSlider.swift
//  VidPreviewQuickLook
//
//  Fancy glass slider component
//

import SwiftUI

// MARK: - Constants

private enum GlassSliderConstants {
    static let thumbSize: CGFloat = 25
    static let hoverThumbSize: CGFloat = 15
    static let idleThumbSize: CGFloat = 10
    static let trackHeight: CGFloat = 4
    static let hitAreaHeight: CGFloat = 25
}

// MARK: - GlassSlider

struct GlassSlider: View {

    // MARK: Public API

    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var tintColor: Color = .blue
    var onChanged: ((Double) -> Void)? = nil
    var onEnded: ((Double) -> Void)? = nil

    // MARK: Private State

    @State private var isHovering = false
    @GestureState private var dragActive = false

    private var isDragging: Bool { dragActive }

    // MARK: Body

    var body: some View {
        GeometryReader { geometry in
            sliderContent(in: geometry)
        }
        .frame(height: GlassSliderConstants.hitAreaHeight)
    }
}

// MARK: - Layout

extension GlassSlider {

    fileprivate func sliderContent(in geometry: GeometryProxy) -> some View {

        let metrics = layoutMetrics(for: geometry.size)

        return ZStack(alignment: .leading) {

            trackView(metrics: metrics, geometry: geometry)

            thumbHalo(metrics: metrics, geometry: geometry)

            thumbView(metrics: metrics, geometry: geometry)
        }
        .contentShape(Rectangle())
        .gesture(dragGesture(in: geometry))
        .onHover { isHovering = $0 }
        .position(
            x: geometry.size.width / 2,
            y: geometry.size.height / 2
        )
    }
}

// MARK: - Subviews

extension GlassSlider {

    fileprivate func trackView(
        metrics: LayoutMetrics,
        geometry: GeometryProxy
    ) -> some View {

        ZStack(alignment: .leading) {

            Capsule()
                .fill(.black.opacity(0.3))
                .frame(height: GlassSliderConstants.trackHeight)
                .offset(y: 1)

            Capsule()
                .fill(Color.secondary.opacity(0.15))
                .frame(height: GlassSliderConstants.trackHeight)

            Capsule()
                .fill(tintColor)
                .frame(
                    width: metrics.fillWidth,
                    height: GlassSliderConstants.trackHeight
                )
                .animation(
                    .spring(response: 0.35, dampingFraction: 0.7),
                    value: isDragging
                )
        }
        .frame(maxWidth: .infinity)
        .frame(height: GlassSliderConstants.hitAreaHeight)
        .layerEffect(
            ShaderLibrary.glass(
                .float2(metrics.thumbCenter),
                .float(GlassSliderConstants.thumbSize / 2),
                .float(isDragging ? 1.0 : 0.0)
            ),
            maxSampleOffset: CGSize(
                width: GlassSliderConstants.thumbSize,
                height: GlassSliderConstants.thumbSize
            )
        )
        .animation(.easeInOut(duration: 0.2), value: isDragging)
    }

    fileprivate func thumbHalo(
        metrics: LayoutMetrics,
        geometry: GeometryProxy
    ) -> some View {

        Circle()
            .stroke(
                AngularGradient(
                    colors: [
                        .white.opacity(0.1),
                        .black.opacity(0.3),
                        .black.opacity(0.3),
                        .white.opacity(0.1),
                    ],
                    center: .center,
                    startAngle: .degrees(135),
                    endAngle: .degrees(405)
                ),
                lineWidth: 2
            )
            .frame(
                width: GlassSliderConstants.thumbSize + 1,
                height: GlassSliderConstants.thumbSize + 1
            )
            .blur(radius: 4)
            .rotationEffect(.degrees(-45))
            .offset(x: metrics.thumbOffset, y: 1)
            .opacity(isDragging ? 1 : 0)
            // Force opacity animation even during a drag transaction
            .transaction { txn in
                txn.animation = .easeInOut(duration: 0.2)
            }
    }

    fileprivate func thumbView(
        metrics: LayoutMetrics,
        geometry: GeometryProxy
    ) -> some View {

        // 1) Moving container (do NOT force animation here)
        ZStack {
            // 2) Visuals (force animation only on these)
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: metrics.visualThumbSize)
                    .opacity(isDragging ? 0 : 1)

                Circle()
                    .fill(.clear)
                    .frame(
                        width: GlassSliderConstants.thumbSize,
                        height: GlassSliderConstants.thumbSize
                    )
                    .opacity(isDragging ? 1 : 0)
            }
            // Force size/opacity animations even while dragging
            .transaction { txn in
                txn.animation = .easeInOut(duration: 0.2)
            }
        }
        .frame(
            width: GlassSliderConstants.thumbSize,
            height: GlassSliderConstants.thumbSize
        )
        .offset(x: metrics.thumbOffset)  // stays “direct”/responsive
    }
}

// MARK: - Layout Metrics

extension GlassSlider {

    fileprivate struct LayoutMetrics {
        let fillWidth: CGFloat
        let thumbOffset: CGFloat
        let thumbCenter: CGPoint
        let visualThumbSize: CGFloat
    }

    fileprivate func layoutMetrics(for size: CGSize) -> LayoutMetrics {

        let normalized = normalizedValue
        let visualSize = currentThumbSize

        let rawX = size.width * CGFloat(normalized)
        let halfVisual = visualSize / 2

        let clampedX = min(
            max(halfVisual, rawX),
            size.width - halfVisual
        )

        let thumbOffset = clampedX - (GlassSliderConstants.thumbSize / 2)

        let center = CGPoint(
            x: thumbOffset + (GlassSliderConstants.thumbSize / 2),
            y: size.height / 2
        )

        return LayoutMetrics(
            fillWidth: size.width * CGFloat(normalized),
            thumbOffset: thumbOffset,
            thumbCenter: center,
            visualThumbSize: visualSize
        )
    }
}

// MARK: - Gestures

extension GlassSlider {

    fileprivate func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragActive) { _, state, _ in
                state = true
            }
            .onChanged { gesture in
                updateValue(
                    for: gesture.location.x,
                    totalWidth: geometry.size.width
                )
            }
            .onEnded { _ in
                onEnded?(value)
            }
    }
}

// MARK: - Value Logic

extension GlassSlider {

    fileprivate var currentThumbSize: CGFloat {
        if isDragging { return GlassSliderConstants.thumbSize }
        if isHovering { return GlassSliderConstants.hoverThumbSize }
        return GlassSliderConstants.idleThumbSize
    }

    fileprivate var normalizedValue: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    fileprivate func updateValue(for x: CGFloat, totalWidth: CGFloat) {
        let clampedX = min(max(0, x), totalWidth)
        let percent = Double(clampedX / totalWidth)

        let newValue =
            range.lowerBound + percent * (range.upperBound - range.lowerBound)

        value = newValue
        onChanged?(newValue)
    }
}
