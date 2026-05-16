//
//  DateScrubber.swift
//  ExyteMediaPicker
//
//  Invisible right-edge touch rail; the date pill is drawn by AlbumDateScrubberOverlay.
//

import SwiftUI

struct DateScrubber: View {

    static let width: CGFloat = 22

    /// > 1 compresses the oldest end of the rail — more finger travel before jumping years.
    private static let progressBiasExponent: CGFloat = 3.1
    /// Minimum vertical travel (fraction of rail) before the active bucket changes.
    private static let minIndexChangeTravelFraction: CGFloat = 0.07

    let sections: [AlbumDateSection]
    var onScrub: (AlbumDateSection, CGFloat) -> Void
    var onScrubEnd: () -> Void

    @State private var lockedSectionIndex: Int = 0
    @State private var indexAnchorY: CGFloat = 0

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
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard !sections.isEmpty, railHeight > 0 else { return }

                let clampedY = max(0, min(value.location.y, railHeight))
                let linearProgress = clampedY / railHeight
                let biasedProgress = pow(linearProgress, Self.progressBiasExponent)
                let candidateIndex = sectionIndex(for: biasedProgress, count: sections.count)

                if candidateIndex != lockedSectionIndex {
                    let minTravel = railHeight * Self.minIndexChangeTravelFraction
                    if indexAnchorY > 0, abs(clampedY - indexAnchorY) < minTravel {
                        onScrub(sections[lockedSectionIndex], clampedY)
                        return
                    }
                    lockedSectionIndex = candidateIndex
                    indexAnchorY = clampedY
                }

                onScrub(sections[lockedSectionIndex], clampedY)
            }
            .onEnded { _ in
                lockedSectionIndex = 0
                indexAnchorY = 0
                onScrubEnd()
            }
    }

    private func sectionIndex(for progress: CGFloat, count: Int) -> Int {
        guard count > 1 else { return 0 }
        let scaled = progress * CGFloat(count - 1)
        return min(max(Int(scaled.rounded(.down)), 0), count - 1)
    }
}
