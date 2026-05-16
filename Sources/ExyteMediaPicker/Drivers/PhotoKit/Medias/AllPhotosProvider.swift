//
//  Created by Alex.M on 09.06.2022.
//

import Foundation
import Photos
import Combine
import SwiftUI

final class AllPhotosProvider: BaseMediasProvider {

    private var lastDeliveredFingerprint: String?
    private var warmupReadyCancellable: AnyCancellable?

    override func reload() {
        PermissionsService.requestPermission { [weak self] in
            self?.reloadAfterPermissionGranted()
        }
    }

    private func reloadAfterPermissionGranted() {
        let mediaType = selectionParamsHolder.mediaType

        if let entry = AllPhotosLibraryCache.shared.entry(for: mediaType) {
            publishFinalSnapshot(entry.models)
            primeVisibleThumbnails(entry.models)
            return
        }

        if MediaPickerWarmup.isWarmingUp(mediaType: mediaType) {
            warmupReadyCancellable = MediaPickerWarmup.libraryCacheReadyPublisher
                .filter { $0 == mediaType }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] readyType in
                    guard let self, readyType == mediaType,
                          let entry = AllPhotosLibraryCache.shared.entry(for: mediaType) else { return }
                    self.publishFinalSnapshot(entry.models)
                    self.primeVisibleThumbnails(entry.models)
                }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let fetchResult = MediasProvider.fetchAssetsFetchResult(mediaSelectionType: mediaType)
            let quickFp = MediasProvider.quickFingerprint(fetchResult: fetchResult)

            if let cached = AllPhotosLibraryCache.shared.entry(for: mediaType),
               cached.quickFingerprint == quickFp {
                DispatchQueue.main.async {
                    self.publishFinalSnapshot(cached.models)
                }
                return
            }

            let assets = MediasProvider.map(fetchResult: fetchResult, mediaSelectionType: mediaType)
            let sections = AlbumDateSectionBuilder.makeSections(from: assets)
            AllPhotosLibraryCache.shared.store(
                models: assets,
                sections: sections,
                mediaType: mediaType,
                quickFingerprint: quickFp
            )
            DispatchQueue.main.async {
                self.publishFinalSnapshot(assets)
                self.primeVisibleThumbnails(assets)
            }
        }
    }

    private func primeVisibleThumbnails(_ assets: [AssetMediaModel]) {
#if os(iOS)
        MediaThumbnailPrefetcher.primeFirstScreenIfNeeded(models: assets)
#endif
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
