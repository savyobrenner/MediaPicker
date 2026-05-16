//
//  AlbumDateScrubberOverlay.swift
//  ExyteMediaPicker
//

import SwiftUI

struct AlbumDateScrubberOverlay: View {

    let sections: [AlbumDateSection]
    let models: [AssetMediaModel]
    let columnsCount: Int
    let scrollProxy: ScrollViewProxy

    @State private var scrubLabel: String = ""
    @State private var scrubLocationY: CGFloat = 0
    @State private var isScrubbing: Bool = false
    @State private var pendingTargetSection: AlbumDateSection?
    @State private var scrollGeneration: UInt = 0
    @State private var activeScrollTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DateScrubber(
                sections: sections,
                onScrub: { section, localY in
                    handleScrub(section: section, localY: localY)
                },
                onScrubEnd: {
                    commitScrollOnScrubEnd()
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
        pendingTargetSection = section
        if !isScrubbing {
            isScrubbing = true
        }
        // Grid scroll happens only on scrub end — live scrollTo on every bucket caused hangs.
    }

    private func commitScrollOnScrubEnd() {
        guard let target = pendingTargetSection else { return }
        pendingTargetSection = nil

        activeScrollTask?.cancel()
        scrollGeneration &+= 1
        let generation = scrollGeneration

        activeScrollTask = Task { @MainActor in
#if os(iOS)
            MediaThumbnailPrefetcher.prefetchWindow(
                models: models,
                around: target.startIndex,
                columnsCount: columnsCount
            )
            // Let PhotoKit start caching before LazyVStack materializes the jump path.
            try? await Task.sleep(nanoseconds: 40_000_000)
#endif
            guard !Task.isCancelled, generation == scrollGeneration else { return }
            performScroll(to: target, generation: generation)
        }
    }

    @MainActor
    private func performScroll(to target: AlbumDateSection, generation: UInt) {
        let targetIndex = target.startIndex

        if targetIndex < 200 {
            scrollOnce(to: target.anchorAssetId)
            return
        }

        let waypointIndex = targetIndex / 2
        let waypoint = sections.last(where: { $0.startIndex <= waypointIndex && $0.id != target.id })

        if let waypoint {
            scrollOnce(to: waypoint.anchorAssetId)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled, generation == scrollGeneration else { return }
                scrollOnce(to: target.anchorAssetId)
            }
        } else {
            scrollOnce(to: target.anchorAssetId)
        }
    }

    private func scrollOnce(to assetId: String) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            scrollProxy.scrollTo(assetId, anchor: .top)
        }
    }
}
