//
//  AlbumDateScrubberOverlay.swift
//  ExyteMediaPicker
//
//  Scrubber UI state lives here so dragging the rail does not rebuild the grid.
//  `scrollTo` runs only when the finger lifts — jumping while dragging freezes
//  SwiftUI lazy stacks on large libraries.
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
                    if let id = pendingScrollAssetId {
                        fireScroll(to: id)
                    }
                    pendingScrollAssetId = nil
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
        if scrubLabel != section.title {
            scrubLabel = section.title
        }
        if !isScrubbing {
            isScrubbing = true
        }
        pendingScrollAssetId = section.items.first?.id
    }

    private func fireScroll(to assetId: String) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            scrollProxy.scrollTo(assetId, anchor: .top)
        }
    }
}
