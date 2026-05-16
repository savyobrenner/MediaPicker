//
//  DateScrubber.swift
//  ExyteMediaPicker
//
//  Invisible right-edge touch rail; the date pill is drawn by AlbumDateScrubberOverlay.
//

import SwiftUI

struct DateScrubber: View {

    static let width: CGFloat = 22

    private static let progressBiasExponent: CGFloat = 1.75

    let sections: [AlbumDateSection]
    var onScrub: (AlbumDateSection, CGFloat) -> Void
    var onScrubEnd: () -> Void

    var body: some View {
        GeometryReader { geo in
            Color.clear
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

                let clampedY = max(0, min(value.location.y, railHeight))
                let linearProgress = clampedY / railHeight
                let biasedProgress = pow(linearProgress, Self.progressBiasExponent)
                let index = sectionIndex(for: biasedProgress, count: sections.count)

                onScrub(sections[index], clampedY)
            }
            .onEnded { _ in
                onScrubEnd()
            }
    }

    private func sectionIndex(for progress: CGFloat, count: Int) -> Int {
        guard count > 1 else { return 0 }
        let scaled = progress * CGFloat(count - 1)
        return min(max(Int(scaled.rounded(.down)), 0), count - 1)
    }
}
