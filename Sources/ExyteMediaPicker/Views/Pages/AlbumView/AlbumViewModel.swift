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
    let anchorAssetId: String
    let startIndex: Int

    var scrollTargetId: String { "album-section-\(id)" }
}

@MainActor
final class AlbumViewModel: ObservableObject {

    @Published var title: String? = nil
    @Published var assetMediaModels: [AssetMediaModel] = []
    @Published var sections: [AlbumDateSection] = []

    @Published private(set) var isAwaitingInitialLibraryLoad = true
    @Published private(set) var masonryColumns: [[AssetMediaModel]] = []

    let mediasProvider: MediasProviderProtocol

    private var mediaCancellable: AnyCancellable?
    private var applyGeneration: UInt = 0
    private var layoutGeneration: UInt = 0
    private var masonryColumnsCount: Int = 3
    private var masonryBuildTask: Task<Void, Never>?

    init(
        mediasProvider: MediasProviderProtocol,
        mediaTypeForCacheHydration: MediaSelectionType? = nil,
        albumMediasCacheKey: String? = nil,
        preloadedLibraryEntry: AllPhotosLibraryCache.Entry? = nil
    ) {
        self.mediasProvider = mediasProvider
        if let entry = preloadedLibraryEntry {
            applyFullLibraryPayload(models: entry.models, sections: entry.sections)
            isAwaitingInitialLibraryLoad = false
        } else if let mediaType = mediaTypeForCacheHydration,
                  let entry = AllPhotosLibraryCache.shared.entry(for: mediaType) {
            applyFullLibraryPayload(models: entry.models, sections: entry.sections)
            isAwaitingInitialLibraryLoad = false
        } else if let cacheKey = albumMediasCacheKey,
                  let entry = AlbumMediasLibraryCache.shared.entry(for: cacheKey) {
            applyFullLibraryPayload(models: entry.models, sections: entry.sections)
            isAwaitingInitialLibraryLoad = false
        }
        onStart()
    }

    func prepareForMediaTypeChange(_ mediaType: MediaSelectionType) {
        if let entry = AllPhotosLibraryCache.shared.entry(for: mediaType) {
            applyFullLibraryPayload(models: entry.models, sections: entry.sections)
            isAwaitingInitialLibraryLoad = false
        } else {
            assetMediaModels = []
            sections = []
            masonryColumns = []
            isAwaitingInitialLibraryLoad = true
        }
    }

    func onStart() {
        mediaCancellable = mediasProvider.assetMediaModelsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] models in
                self?.handleIncomingModels(models)
            }

        guard assetMediaModels.isEmpty else { return }
        mediasProvider.reload()
    }

    func rebuildMasonryColumns(count: Int) {
        guard count > 0, count != masonryColumnsCount || masonryColumns.isEmpty else { return }
        masonryColumnsCount = count
        scheduleMasonryBuild(models: assetMediaModels, columnsCount: count)
    }

    private func handleIncomingModels(_ models: [AssetMediaModel]) {
        if models.isEmpty {
            isAwaitingInitialLibraryLoad = false
            assetMediaModels = []
            sections = []
            masonryColumns = []
            return
        }

        isAwaitingInitialLibraryLoad = false

        applyGeneration &+= 1
        let generation = applyGeneration

        if let cached = AllPhotosLibraryCache.shared.entry(matchingModels: models),
           !cached.sections.isEmpty {
            applyFullLibraryPayload(models: models, sections: cached.sections)
            return
        }

        Task.detached(priority: .userInitiated) { [generation] in
            let builtSections = AlbumDateSectionBuilder.makeSections(from: models)
            await MainActor.run { [weak self] in
                guard let self, generation == self.applyGeneration else { return }
                self.applyFullLibraryPayload(models: models, sections: builtSections)
            }
        }
    }

    private func applyFullLibraryPayload(models: [AssetMediaModel], sections: [AlbumDateSection]) {
        assetMediaModels = models
        self.sections = sections
        layoutGeneration &+= 1
        scheduleMasonryBuild(models: models, columnsCount: masonryColumnsCount)
#if os(iOS)
        MediaThumbnailPrefetcher.primeFirstScreenIfNeeded(models: models)
#endif
    }

    private func scheduleMasonryBuild(models: [AssetMediaModel], columnsCount: Int) {
        masonryBuildTask?.cancel()
        let generation = layoutGeneration
        masonryBuildTask = Task.detached(priority: .userInitiated) { [weak self] in
            let columns = Self.distributeIntoColumns(models, count: max(columnsCount, 1))
            await MainActor.run {
                guard let self, !Task.isCancelled, generation == self.layoutGeneration else { return }
                self.masonryColumns = columns
            }
        }
    }

    nonisolated private static func distributeIntoColumns(_ items: [AssetMediaModel], count: Int) -> [[AssetMediaModel]] {
        guard count > 0 else { return [items] }
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

    nonisolated private static func aspectRatio(for item: AssetMediaModel) -> CGFloat {
        let a = item.asset
        let w = CGFloat(max(a.pixelWidth, 1))
        let h = CGFloat(max(a.pixelHeight, 1))
        return w / h
    }

    deinit {
        masonryBuildTask?.cancel()
        mediasProvider.cancel()
        mediaCancellable = nil
    }
}
