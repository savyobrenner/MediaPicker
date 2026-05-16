//
//  Created by Alex.M on 09.06.2022.
//

import Foundation
import Photos
import Combine
import SwiftUI

final class AllPhotosProvider: BaseMediasProvider {

    private var lastDeliveredFingerprint: String?
    private static let publishBatchSize = 180

    override func reload() {
        PermissionsService.requestPermission { [weak self] in
            self?.reloadAfterPermissionGranted()
        }
    }

    private func reloadAfterPermissionGranted() {
        let mediaType = selectionParamsHolder.mediaType

        if let entry = AllPhotosLibraryCache.shared.entry(for: mediaType) {
            publishFinalSnapshot(entry.models)
#if os(iOS)
            MediaThumbnailPrefetcher.prefetchThumbnailGridPriming(models: entry.models, columnsCount: 3)
#endif
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let fetchResult = MediasProvider.fetchAssetsFetchResult(mediaSelectionType: mediaType)
            let quickFp = MediasProvider.quickFingerprint(fetchResult: fetchResult)

            if let cached = AllPhotosLibraryCache.shared.entry(for: mediaType),
               cached.quickFingerprint == quickFp {
                return
            }

            let total = fetchResult.count
            guard total > 0 else {
                DispatchQueue.main.async {
                    self.publishFinalSnapshot([])
                }
                return
            }

            var accumulated: [AssetMediaModel] = []
            accumulated.reserveCapacity(total)

            for index in 0..<total {
                let asset = fetchResult.object(at: index)
                if (asset.mediaType == .image && mediaType.allowsPhoto)
                    || (asset.mediaType == .video && mediaType.allowsVideo) {
                    accumulated.append(AssetMediaModel(asset: asset))
                }

                let isLast = index == total - 1
                let shouldFlush = accumulated.count.isMultiple(of: Self.publishBatchSize) || isLast
                guard shouldFlush, !accumulated.isEmpty else { continue }

                let snapshot = accumulated
                DispatchQueue.main.async {
                    if isLast {
                        let sections = AlbumDateSectionBuilder.makeSections(from: snapshot)
                        AllPhotosLibraryCache.shared.store(
                            models: snapshot,
                            sections: sections,
                            mediaType: mediaType,
                            quickFingerprint: quickFp
                        )
                        self.publishFinalSnapshot(snapshot)
#if os(iOS)
                        MediaThumbnailPrefetcher.prefetchThumbnailGridPriming(models: snapshot, columnsCount: 3)
#endif
                    } else {
                        self.publishStreamingSnapshot(snapshot)
                    }
                }
            }
        }
    }

    private func publishStreamingSnapshot(_ assets: [AssetMediaModel]) {
        guard filterClosure == nil, massFilterClosure == nil else {
            publishFinalSnapshot(assets)
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.assetMediaModelsPublisher.send(assets)
        }
    }

    private func publishFinalSnapshot(_ assets: [AssetMediaModel]) {
        let fingerprint = Self.fingerprint(for: assets)
        if filterClosure == nil, massFilterClosure == nil, fingerprint == lastDeliveredFingerprint {
            return
        }
        if filterClosure == nil, massFilterClosure == nil {
            lastDeliveredFingerprint = fingerprint
        }
        filterAndPublish(assets: assets)
    }

    private static func fingerprint(for assets: [AssetMediaModel]) -> String {
        guard let first = assets.first, let last = assets.last else {
            return "empty"
        }
        return "\(assets.count)|\(first.id)|\(last.id)"
    }
}
