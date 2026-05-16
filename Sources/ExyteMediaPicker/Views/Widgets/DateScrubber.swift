//
//  DateScrubber.swift
//  ExyteMediaPicker
//
//  Invisible right-edge touch rail; the date pill is drawn by AlbumDateScrubberOverlay.
//

import SwiftUI

struct DateScrubber: View {

    static let width: CGFloat = 22

    let sections: [AlbumDateSection]
    /// Total assets in the album — scrub position maps to **photo count**, not section count.
    let totalAssetCount: Int
    var onScrub: (AlbumDateSection, CGFloat, Int) -> Void
    var onScrubEnd: () -> Void

    @State private var lockedAssetIndex: Int = 0
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
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !sections.isEmpty, railHeight > 0, totalAssetCount > 0 else { return }

                let clampedY = max(0, min(value.location.y, railHeight))
                let progress = clampedY / railHeight
                let candidateIndex = AlbumDateScrubMapping.assetIndex(
                    progress: progress,
                    totalCount: totalAssetCount
                )

                if candidateIndex != lockedAssetIndex {
                    let minIndexStep = max(totalAssetCount / 100, 30)
                    let minTravel = railHeight * 0.035
                    if indexAnchorY > 0,
                       abs(candidateIndex - lockedAssetIndex) < minIndexStep,
                       abs(clampedY - indexAnchorY) < minTravel {
                        emitScrub(at: lockedAssetIndex, localY: clampedY)
                        return
                    }
                    lockedAssetIndex = candidateIndex
                    indexAnchorY = clampedY
                }

                emitScrub(at: lockedAssetIndex, localY: clampedY)
            }
            .onEnded { _ in
                lockedAssetIndex = 0
                indexAnchorY = 0
                onScrubEnd()
            }
    }

    private func emitScrub(at assetIndex: Int, localY: CGFloat) {
        guard let section = sections.section(containingAssetIndex: assetIndex) else { return }
        onScrub(section, localY, assetIndex)
    }
}
