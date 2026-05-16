//
//  DateScrubber.swift
//  ExyteMediaPicker
//
//  Right-edge scrubber. Finger position is mapped with a power curve so recent
//  photos occupy more of the rail — small movements stay near “today”.
//

import SwiftUI

struct DateScrubber: View {

    static let width: CGFloat = 22

    /// Exponent > 1 compresses the bottom of the rail (older dates need more drag).
    private static let progressBiasExponent: CGFloat = 1.75

    let sections: [AlbumDateSection]
    var onScrub: (AlbumDateSection, CGFloat) -> Void
    var onScrubEnd: () -> Void

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Capsule()
                    .fill(Color.secondary.opacity(isDragging ? 0.7 : 0.25))
                    .frame(width: isDragging ? 3 : 2)
                    .padding(.vertical, 6)
                    .animation(.easeOut(duration: 0.15), value: isDragging)
            }
            .frame(width: Self.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(scrubGesture(railHeight: geo.size.height))
        }
        .frame(width: Self.width)
    }

    private func scrubGesture(railHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard !sections.isEmpty, railHeight > 0 else { return }
                isDragging = true

                let clampedY = max(0, min(value.location.y, railHeight))
                let linearProgress = clampedY / railHeight
                let biasedProgress = pow(linearProgress, Self.progressBiasExponent)
                let index = sectionIndex(for: biasedProgress, count: sections.count)

                onScrub(sections[index], clampedY)
            }
            .onEnded { _ in
                isDragging = false
                onScrubEnd()
            }
    }

    private func sectionIndex(for progress: CGFloat, count: Int) -> Int {
        guard count > 1 else { return 0 }
        let scaled = progress * CGFloat(count - 1)
        return min(max(Int(scaled.rounded(.down)), 0), count - 1)
    }
}
