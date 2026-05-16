//
//  Created by Alex.M on 09.06.2022.
//

import Foundation
import Photos
import Combine
import SwiftUI

final class AllPhotosProvider: BaseMediasProvider {

    private var lastDeliveredFingerprint: String?

    override func reload() {
        PermissionsService.requestPermission { [weak self] in
            self?.reloadAfterPermissionGranted()
        }
    }

    private func reloadAfterPermissionGranted() {
        let mediaType = selectionParamsHolder.mediaType

        if let cached = AllPhotosLibraryCache.shared.models(for: mediaType) {
            publishAssetsIfChanged(cached)
#if os(iOS)
            MediaThumbnailPrefetcher.prefetchThumbnailGridPriming(models: cached, columnsCount: 3)
#endif
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let assets = MediasProvider.fetchAllAssetModels(mediaSelectionType: mediaType)
            AllPhotosLibraryCache.shared.store(assets, mediaType: mediaType)
            DispatchQueue.main.async {
                self.publishAssetsIfChanged(assets)
#if os(iOS)
                MediaThumbnailPrefetcher.prefetchThumbnailGridPriming(models: assets, columnsCount: 3)
#endif
            }
        }
    }

    private func publishAssetsIfChanged(_ assets: [AssetMediaModel]) {
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
