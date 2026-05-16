//
//  AlbumDateScrubberOverlay.swift
//  ExyteMediaPicker
//
//  Scrubber state is isolated from the grid. `scrollTo` is throttled while dragging
//  so the timeline moves with the finger without blocking the main thread.
//

import SwiftUI

struct AlbumDateScrubberOverlay: View {

    let sections: [AlbumDateSection]
    let scrollProxy: ScrollViewProxy

    @State private var scrubLabel: String = ""
    @State private var scrubLocationY: CGFloat = 0
    @State private var isScrubbing: Bool = false
    @State private var lastScrolledSectionId: String?
    @State private var lastScrollFireTime: CFAbsoluteTime = 0
    @State private var pendingScrollWork: DispatchWorkItem?

    private let scrollThrottleSeconds: CFAbsoluteTime = 0.14

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DateScrubber(
                sections: sections,
                onScrub: { section, localY in
                    handleScrub(section: section, localY: localY)
                },
                onScrubEnd: {
                    pendingScrollWork?.cancel()
                    pendingScrollWork = nil
                    lastScrolledSectionId = nil
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

        guard section.id != lastScrolledSectionId else { return }
        guard let targetId = section.items.first?.id else { return }

        let now = CFAbsoluteTimeGetCurrent()
        if now - lastScrollFireTime >= scrollThrottleSeconds {
            performScroll(to: targetId, sectionId: section.id)
            return
        }

        pendingScrollWork?.cancel()
        let delay = scrollThrottleSeconds - (now - lastScrollFireTime)
        let capturedId = targetId
        let capturedSectionId = section.id
        let work = DispatchWorkItem {
            performScroll(to: capturedId, sectionId: capturedSectionId)
        }
        pendingScrollWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func performScroll(to assetId: String, sectionId: String) {
        lastScrolledSectionId = sectionId
        lastScrollFireTime = CFAbsoluteTimeGetCurrent()
        pendingScrollWork = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            scrollProxy.scrollTo(assetId, anchor: .center)
        }
    }
}
