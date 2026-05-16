//
//  Created by Alex.M on 09.06.2022.
//

import Foundation
import Combine
import Photos
import CoreGraphics

/// Logical section grouping assets by creation date the same way the
/// iOS 26 Photos app does: "Today", "Yesterday", "September 12",
/// "September 2025"...
struct AlbumDateSection: Identifiable, Equatable {
    let id: String
    let title: String
    let items: [AssetMediaModel]
}

@MainActor
final class AlbumViewModel: ObservableObject {

    @Published var title: String? = nil
    @Published var assetMediaModels: [AssetMediaModel] = []
    @Published var sections: [AlbumDateSection] = []

    /// True until the first payload arrives from PhotoKit (often async off the main thread).
    @Published private(set) var isAwaitingInitialLibraryLoad = true

    private var layoutGeneration: UInt = 0

    let mediasProvider: MediasProviderProtocol

    private var mediaCancellable: AnyCancellable?
    private var applyGeneration: UInt = 0

    private var masonryDistCacheKey: (generation: UInt, columns: Int)?
    private var masonryDistCached: [[AssetMediaModel]] = []

    /// Pass `mediaTypeForCacheHydration` for the “All photos” provider so reopening the picker can paint instantly from cache.
    init(mediasProvider: MediasProviderProtocol, mediaTypeForCacheHydration: MediaSelectionType? = nil) {
        self.mediasProvider = mediasProvider
        if let mediaType = mediaTypeForCacheHydration,
           let entry = AllPhotosLibraryCache.shared.entry(for: mediaType) {
            applyLibraryPayload(models: entry.models, sections: entry.sections, bumpLayout: true)
            isAwaitingInitialLibraryLoad = false
        }
        onStart()
    }

    func prepareForMediaTypeChange(_ mediaType: MediaSelectionType) {
        if let entry = AllPhotosLibraryCache.shared.entry(for: mediaType) {
            applyLibraryPayload(models: entry.models, sections: entry.sections, bumpLayout: true)
            isAwaitingInitialLibraryLoad = false
        } else {
            assetMediaModels = []
            sections = []
            isAwaitingInitialLibraryLoad = true
        }
    }

    func onStart() {
        mediaCancellable = mediasProvider.assetMediaModelsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] models in
                self?.handleIncomingModels(models)
            }

        mediasProvider.reload()
    }

    private func handleIncomingModels(_ models: [AssetMediaModel]) {
        let generation = applyGeneration &+ 1
        applyGeneration = generation

        // Already sorted by PhotoKit fetch (modificationDate desc); skip O(n log n) re-sort.
        if let cached = AllPhotosLibraryCache.shared.entry(matchingModels: models),
           !cached.sections.isEmpty {
            applyLibraryPayload(models: models, sections: cached.sections, bumpLayout: true)
            isAwaitingInitialLibraryLoad = false
            return
        }

        Task.detached(priority: .userInitiated) { [generation] in
            let builtSections = AlbumDateSectionBuilder.makeSections(from: models)
            await MainActor.run { [weak self] in
                guard let self, generation == self.applyGeneration else { return }
                self.applyLibraryPayload(models: models, sections: builtSections, bumpLayout: true)
                self.isAwaitingInitialLibraryLoad = false
            }
        }
    }

    private func applyLibraryPayload(
        models: [AssetMediaModel],
        sections: [AlbumDateSection],
        bumpLayout: Bool
    ) {
        assetMediaModels = models
        self.sections = sections
        if bumpLayout {
            layoutGeneration &+= 1
            masonryDistCacheKey = nil
        }
    }

    /// Cached masonry column buckets — recomputing while scrubbing was forcing O(n) work every frame.
    func masonryDistribution(forColumnsCount columnsCount: Int) -> [[AssetMediaModel]] {
        guard columnsCount > 0 else { return [assetMediaModels] }
        let key = (layoutGeneration, columnsCount)
        if masonryDistCacheKey?.generation == key.0, masonryDistCacheKey?.columns == key.1 {
            return masonryDistCached
        }
        masonryDistCached = Self.distributeIntoColumns(assetMediaModels, count: columnsCount)
        masonryDistCacheKey = key
        return masonryDistCached
    }

    private static func distributeIntoColumns(_ items: [AssetMediaModel], count: Int) -> [[AssetMediaModel]] {
        var columns: [[AssetMediaModel]] = Array(repeating: [], count: count)
        var heights: [Double] = Array(repeating: 0, count: count)

        for item in items {
            let aspect = Self.aspectRatio(for: item)
            let h = aspect > 0 ? 1.0 / Double(aspect) : 1.0
            var minIndex = 0
            for i in 1..<count where heights[i] + 0.0001 < heights[minIndex] {
                minIndex = i
            }
            columns[minIndex].append(item)
            heights[minIndex] += h
        }
        return columns
    }

    private static func aspectRatio(for item: AssetMediaModel) -> CGFloat {
        let a = item.asset
        let w = CGFloat(max(a.pixelWidth, 1))
        let h = CGFloat(max(a.pixelHeight, 1))
        return w / h
    }

    deinit {
        mediasProvider.cancel()
        mediaCancellable = nil
    }
}
