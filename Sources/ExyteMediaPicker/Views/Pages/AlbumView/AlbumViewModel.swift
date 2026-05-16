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
}

@MainActor
final class AlbumViewModel: ObservableObject {

    @Published var title: String? = nil
    @Published var assetMediaModels: [AssetMediaModel] = []
    @Published var sections: [AlbumDateSection] = []

    @Published private(set) var isAwaitingInitialLibraryLoad = true

    let mediasProvider: MediasProviderProtocol

    private var mediaCancellable: AnyCancellable?
    private var applyGeneration: UInt = 0

    /// Masonry columns per date section (small chunks — not the whole library).
    private var sectionMasonryCache: [String: [[AssetMediaModel]]] = [:]
    private var sectionMasonryColumnsCount: Int = 0

    init(mediasProvider: MediasProviderProtocol, mediaTypeForCacheHydration: MediaSelectionType? = nil) {
        self.mediasProvider = mediasProvider
        if let mediaType = mediaTypeForCacheHydration,
           let entry = AllPhotosLibraryCache.shared.entry(for: mediaType) {
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
            clearSectionMasonryCache()
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

    func items(forSectionAt sectionIndex: Int) -> [AssetMediaModel] {
        guard sections.indices.contains(sectionIndex) else { return [] }
        let start = sections[sectionIndex].startIndex
        let end: Int
        if sectionIndex + 1 < sections.count {
            end = sections[sectionIndex + 1].startIndex
        } else {
            end = assetMediaModels.count
        }
        guard start < end, end <= assetMediaModels.count else { return [] }
        return Array(assetMediaModels[start..<end])
    }

    func masonryColumns(forSectionAt sectionIndex: Int, columnsCount: Int) -> [[AssetMediaModel]] {
        guard sections.indices.contains(sectionIndex), columnsCount > 0 else { return [] }
        let section = sections[sectionIndex]
        if sectionMasonryColumnsCount != columnsCount {
            clearSectionMasonryCache()
            sectionMasonryColumnsCount = columnsCount
        }
        if let cached = sectionMasonryCache[section.id] {
            return cached
        }
        let items = items(forSectionAt: sectionIndex)
        let columns = Self.distributeIntoColumns(items, count: columnsCount)
        sectionMasonryCache[section.id] = columns
        return columns
    }

    private func handleIncomingModels(_ models: [AssetMediaModel]) {
        if models.isEmpty {
            isAwaitingInitialLibraryLoad = false
            assetMediaModels = []
            sections = []
            clearSectionMasonryCache()
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
        clearSectionMasonryCache()
    }

    private func clearSectionMasonryCache() {
        sectionMasonryCache.removeAll()
        sectionMasonryColumnsCount = 0
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
    }
}
