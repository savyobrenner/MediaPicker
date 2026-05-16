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
    let models: [AssetMediaModel]
    /// Visible viewport height — must NOT be scroll content height.
    let railHeight: CGFloat
    var onScrub: (AlbumDateSection, CGFloat, Int) -> Void
    var onScrubEnd: () -> Void

    @State private var lockedAssetIndex: Int = 0
    @State private var indexAnchorY: CGFloat = 0

    var body: some View {
        Color.clear
            .frame(width: Self.width, height: max(railHeight, 1))
            .contentShape(Rectangle())
            .gesture(scrubGesture)
    }

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !sections.isEmpty, !models.isEmpty, railHeight > 1 else { return }

                let clampedY = max(0, min(value.location.y, railHeight))
                let progress = clampedY / railHeight
                let candidateIndex = AlbumDateScrubMapping.assetIndex(
                    progress: progress,
                    models: models
                )

                if candidateIndex != lockedAssetIndex {
                    let minIndexStep = max(models.count / 120, 40)
                    let minTravel = railHeight * 0.045
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
