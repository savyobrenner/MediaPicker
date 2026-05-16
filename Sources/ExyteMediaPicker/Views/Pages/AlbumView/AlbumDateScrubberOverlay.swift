//
//  AlbumDateScrubberOverlay.swift
//  ExyteMediaPicker
//

import SwiftUI

struct AlbumDateScrubberOverlay: View {

    let sections: [AlbumDateSection]
    let models: [AssetMediaModel]
    let columnsCount: Int
    let visibleHeight: CGFloat
    let scrollProxy: ScrollViewProxy

    @State private var scrubLabel: String = ""
    @State private var scrubLocationY: CGFloat = 0
    @State private var isScrubbing: Bool = false
    @State private var lastScrolledSectionId: String?
    @State private var lastScrollTimestamp: CFAbsoluteTime = 0
    @State private var lastCommittedScrollIndex: Int = 0
    @State private var fingerTargetIndex: Int = 0
    @State private var scrollGeneration: UInt = 0
    @State private var activeScrollTask: Task<Void, Never>?

    private let maxLiveScrollStep: Int = 200
    private let liveScrollThrottleSeconds: CFAbsoluteTime = 0.15

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isScrubbing, !scrubLabel.isEmpty {
                Text(scrubLabel)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.thinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 2)
                    .padding(.trailing, DateScrubber.width + 10)
                    .offset(y: max(scrubLocationY - 18, 8))
                    .allowsHitTesting(false)
            }

            DateScrubber(
                sections: sections,
                models: models,
                railHeight: visibleHeight,
                onScrub: { section, localY, targetIndex in
                    handleScrub(section: section, localY: localY, targetIndex: targetIndex)
                },
                onScrubEnd: {
                    finishScrub()
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: visibleHeight, alignment: .topTrailing)
    }

    private func handleScrub(section: AlbumDateSection, localY: CGFloat, targetIndex: Int) {
        scrubLocationY = localY
        scrubLabel = AlbumDateScrubLabel.title(for: targetIndex, in: models)
        fingerTargetIndex = targetIndex

        if !isScrubbing {
            isScrubbing = true
            activeScrollTask?.cancel()
            lastCommittedScrollIndex = targetIndex
            lastScrolledSectionId = section.id
            return
        }

        let isNewSection = section.id != lastScrolledSectionId
        let now = CFAbsoluteTimeGetCurrent()
        let throttleElapsed = now - lastScrollTimestamp >= liveScrollThrottleSeconds
        guard isNewSection || throttleElapsed else { return }

        lastScrolledSectionId = section.id
        lastScrollTimestamp = now
        scheduleScroll(toward: targetIndex, live: true)
    }

    private func finishScrub() {
        withAnimation(.easeOut(duration: 0.2)) {
            isScrubbing = false
        }
        lastScrolledSectionId = nil

        guard fingerTargetIndex >= 0 else { return }
        scheduleScroll(toward: fingerTargetIndex, live: false)
    }

    private func scheduleScroll(toward targetIndex: Int, live: Bool) {
        activeScrollTask?.cancel()
        scrollGeneration &+= 1
        let generation = scrollGeneration

        activeScrollTask = Task { @MainActor in
            let steps = scrollIndexSteps(
                from: lastCommittedScrollIndex,
                to: targetIndex,
                live: live
            )

            for stepIndex in steps {
                guard !Task.isCancelled, generation == scrollGeneration else { return }
                guard let section = sections.section(containingAssetIndex: stepIndex) else { continue }

#if os(iOS)
                MediaThumbnailPrefetcher.prefetchWindow(
                    models: models,
                    around: stepIndex,
                    columnsCount: columnsCount
                )
                if !live, steps.count > 1 {
                    try? await Task.sleep(nanoseconds: 80_000_000)
                } else if live {
                    try? await Task.sleep(nanoseconds: 20_000_000)
                }
#endif
                guard !Task.isCancelled, generation == scrollGeneration else { return }
                scrollOnce(to: section.anchorAssetId)
                lastCommittedScrollIndex = stepIndex
            }
        }
    }

    private func scrollIndexSteps(from: Int, to: Int, live: Bool) -> [Int] {
        guard from != to else { return [] }

        if !live {
            return chunkedSteps(from: from, to: to, chunkSize: 700)
        }

        let delta = to - from
        if abs(delta) <= maxLiveScrollStep {
            return [to]
        }
        return [from + (delta > 0 ? maxLiveScrollStep : -maxLiveScrollStep)]
    }

    private func chunkedSteps(from: Int, to: Int, chunkSize: Int) -> [Int] {
        var steps: [Int] = []
        var current = from
        while current != to {
            let remaining = to - current
            if abs(remaining) <= chunkSize {
                current = to
            } else {
                current += remaining > 0 ? chunkSize : -chunkSize
            }
            steps.append(current)
        }
        return steps
    }

    private func scrollOnce(to assetId: String) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            scrollProxy.scrollTo(assetId, anchor: .top)
        }
    }
}
