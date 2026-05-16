//
//  Created by Alex.M on 09.06.2022.
//

import Foundation
import Combine
import Photos
import CoreGraphics

struct AlbumDateSection: Identifiable, Equatable {
    let id: String
    let title: String
    /// First asset in this date bucket — used by the scrubber for `scrollTo` (no per-section asset arrays).
    let anchorAssetId: String
}

@MainActor
final class AlbumViewModel: ObservableObject {

    @Published var title: String? = nil
    @Published var assetMediaModels: [AssetMediaModel] = []
    @Published var sections: [AlbumDateSection] = []

    /// False as soon as we can show tiles (cache, placeholders, or first streamed batch).
    @Published private(set) var isAwaitingInitialLibraryLoad = true
    /// True while PhotoKit is still appending batches (footer indicator only).
    @Published private(set) var isStreamingLibraryIndex = false

    private var layoutGeneration: UInt = 0

    let mediasProvider: MediasProviderProtocol

    private var mediaCancellable: AnyCancellable?
    private var applyGeneration: UInt = 0
    private var sectionsRebuildTask: Task<Void, Never>?

    private var masonryDistCacheKey: (generation: UInt, columns: Int)?
    private var masonryDistCached: [[AssetMediaModel]] = []
    private var masonryColumnHeights: [Double] = []

    init(mediasProvider: MediasProviderProtocol, mediaTypeForCacheHydration: MediaSelectionType? = nil) {
        self.mediasProvider = mediasProvider
        if let mediaType = mediaTypeForCacheHydration,
           let entry = AllPhotosLibraryCache.shared.entry(for: mediaType) {
            applyFullLibraryPayload(models: entry.models, sections: entry.sections)
            isAwaitingInitialLibraryLoad = false
            isStreamingLibraryIndex = false
#if os(iOS)
            MediaThumbnailPrefetcher.prefetchThumbnailGridPriming(models: entry.models, columnsCount: 3, maxAssets: 200)
#endif
        }
        onStart()
    }

    func prepareForMediaTypeChange(_ mediaType: MediaSelectionType) {
        if let entry = AllPhotosLibraryCache.shared.entry(for: mediaType) {
            applyFullLibraryPayload(models: entry.models, sections: entry.sections)
            isAwaitingInitialLibraryLoad = false
            isStreamingLibraryIndex = false
        } else {
            assetMediaModels = []
            sections = []
            masonryDistCached = []
            masonryColumnHeights = []
            isAwaitingInitialLibraryLoad = true
            isStreamingLibraryIndex = true
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
        if models.isEmpty {
            isAwaitingInitialLibraryLoad = false
            isStreamingLibraryIndex = false
            assetMediaModels = []
            sections = []
            masonryDistCached = []
            masonryColumnHeights = []
            return
        }

        isAwaitingInitialLibraryLoad = false

        if isStreamingAppend(of: models) {
            appendStreamingBatch(models)
            scheduleSectionsRebuild(for: models)
            return
        }

        applyGeneration &+= 1
        let generation = applyGeneration
        let likelyMoreBatches = models.count >= 180 && models.count.isMultiple(of: 180)

        if let cached = AllPhotosLibraryCache.shared.entry(matchingModels: models),
           !cached.sections.isEmpty {
            applyFullLibraryPayload(models: models, sections: cached.sections)
            isStreamingLibraryIndex = false
            return
        }

        isStreamingLibraryIndex = likelyMoreBatches

        Task.detached(priority: .userInitiated) { [generation] in
            let builtSections = AlbumDateSectionBuilder.makeSections(from: models)
            await MainActor.run { [weak self] in
                guard let self, generation == self.applyGeneration else { return }
                self.applyFullLibraryPayload(models: models, sections: builtSections)
                if !likelyMoreBatches {
                    self.isStreamingLibraryIndex = false
                }
            }
        }
    }

    private func isStreamingAppend(of models: [AssetMediaModel]) -> Bool {
        guard !assetMediaModels.isEmpty,
              models.count > assetMediaModels.count else {
            return false
        }
        let prefixCount = assetMediaModels.count
        return models[prefixCount - 1].id == assetMediaModels[prefixCount - 1].id
    }

    private func appendStreamingBatch(_ models: [AssetMediaModel]) {
        isStreamingLibraryIndex = true
        let previousCount = assetMediaModels.count
        assetMediaModels = models
        let newItems = Array(models[previousCount...])
        guard !newItems.isEmpty else { return }
        layoutGeneration &+= 1
        appendToMasonryColumns(newItems, columnsCount: 3)
    }

    private func scheduleSectionsRebuild(for models: [AssetMediaModel]) {
        sectionsRebuildTask?.cancel()
        let generation = applyGeneration
        sectionsRebuildTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            let built = AlbumDateSectionBuilder.makeSections(from: models)
            await MainActor.run { [weak self] in
                guard let self, generation == self.applyGeneration else { return }
                self.sections = built
            }
        }
    }

    private func applyFullLibraryPayload(models: [AssetMediaModel], sections: [AlbumDateSection]) {
        sectionsRebuildTask?.cancel()
        assetMediaModels = models
        self.sections = sections
        layoutGeneration &+= 1
        rebuildMasonryColumns(count: 3)
        isStreamingLibraryIndex = false
#if os(iOS)
        MediaThumbnailPrefetcher.prefetchThumbnailGridPriming(models: models, columnsCount: 3)
#endif
    }

    func masonryDistribution(forColumnsCount columnsCount: Int) -> [[AssetMediaModel]] {
        guard columnsCount > 0 else { return [assetMediaModels] }
        let key = (layoutGeneration, columnsCount)
        if masonryDistCacheKey?.generation == key.0,
           masonryDistCacheKey?.columns == key.1,
           masonryDistCached.count == columnsCount {
            return masonryDistCached
        }
        rebuildMasonryColumns(count: columnsCount)
        masonryDistCacheKey = key
        return masonryDistCached
    }

    private func rebuildMasonryColumns(count: Int) {
        masonryDistCached = Self.distributeIntoColumns(assetMediaModels, count: count)
        masonryColumnHeights = columnHeights(for: masonryDistCached, count: count)
    }

    private func appendToMasonryColumns(_ newItems: [AssetMediaModel], columnsCount: Int) {
        if masonryDistCached.count != columnsCount || masonryColumnHeights.count != columnsCount {
            rebuildMasonryColumns(count: columnsCount)
            return
        }
        for item in newItems {
            let aspect = Self.aspectRatio(for: item)
            let h = aspect > 0 ? 1.0 / Double(aspect) : 1.0
            var minIndex = 0
            for i in 1..<columnsCount where masonryColumnHeights[i] + 0.0001 < masonryColumnHeights[minIndex] {
                minIndex = i
            }
            masonryDistCached[minIndex].append(item)
            masonryColumnHeights[minIndex] += h
        }
    }

    private func columnHeights(for columns: [[AssetMediaModel]], count: Int) -> [Double] {
        var heights = Array(repeating: 0.0, count: count)
        for columnIndex in 0..<count {
            for item in columns[columnIndex] {
                let aspect = Self.aspectRatio(for: item)
                heights[columnIndex] += aspect > 0 ? 1.0 / Double(aspect) : 1.0
            }
        }
        return heights
    }

    private static func distributeIntoColumns(_ items: [AssetMediaModel], count: Int) -> [[AssetMediaModel]] {
        var columns: [[AssetMediaModel]] = Array(repeating: [], count: count)
        var heights: [Double] = Array(repeating: 0, count: count)

        for item in items {
            let aspect = aspectRatio(for: item)
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
        sectionsRebuildTask?.cancel()
    }
}
