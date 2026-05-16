//
//  AlbumDateScrubberOverlay.swift
//  ExyteMediaPicker
//
//  While dragging: floating date label tracks the finger. The grid scrolls once
//  when the finger lifts (avoids hammering `scrollTo` on huge libraries).
//

import SwiftUI

struct AlbumDateScrubberOverlay: View {

    let sections: [AlbumDateSection]
    let scrollProxy: ScrollViewProxy

    @State private var scrubLabel: String = ""
    @State private var scrubLocationY: CGFloat = 0
    @State private var isScrubbing: Bool = false
    @State private var pendingScrollAssetId: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DateScrubber(
                sections: sections,
                onScrub: { section, localY in
                    handleScrub(section: section, localY: localY)
                },
                onScrubEnd: {
                    commitPendingScroll()
                    withAnimation(.easeOut(duration: 0.2)) {
                        isScrubbing = false
                    }
                }
            )

            if isScrubbing {
                Text(scrubLabel)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.thinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 2)
                    .padding(.trailing, DateScrubber.width + 8)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .offset(y: max(scrubLocationY - 18, 0))
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
    }

    private func handleScrub(section: AlbumDateSection, localY: CGFloat) {
        scrubLocationY = localY
        scrubLabel = section.title
        pendingScrollAssetId = section.anchorAssetId
        if !isScrubbing {
            isScrubbing = true
        }
    }

    private func commitPendingScroll() {
        guard let assetId = pendingScrollAssetId else { return }
        pendingScrollAssetId = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            scrollProxy.scrollTo(assetId, anchor: .top)
        }
    }
}
