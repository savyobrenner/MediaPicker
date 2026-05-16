//
//  Created by Alex.M on 09.06.2022.
//

import Foundation
import Combine
import Photos
import SwiftUI

final class AlbumMediasProvider: BaseMediasProvider {

    let album: AlbumModel

    init(album: AlbumModel, selectionParamsHolder: SelectionParamsHolder, filterClosure: MediaPicker.FilterClosure? = nil, massFilterClosure: MediaPicker.MassFilterClosure? = nil, showingLoadingCell: Binding<Bool>) {
        self.album = album
        super.init(selectionParamsHolder: selectionParamsHolder, filterClosure: filterClosure, massFilterClosure: massFilterClosure, showingLoadingCell: showingLoadingCell)
    }

    override func reload() {
        PermissionsService.requestPermission { [weak self] in
            self?.reloadInternal()
        }
    }

    func reloadInternal() {
        let collection = album.source
        let mediaType = selectionParamsHolder.mediaType
        let cacheKey = AlbumMediasLibraryCache.shared.cacheKey(albumId: album.id, mediaType: mediaType)

        if let entry = AlbumMediasLibraryCache.shared.entry(for: cacheKey) {
            filterAndPublish(assets: entry.models)
#if os(iOS)
            MediaThumbnailPrefetcher.primeFirstScreenIfNeeded(models: entry.models)
#endif
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let options = PHFetchOptions()
            options.sortDescriptors = [
                NSSortDescriptor(key: "creationDate", ascending: false)
            ]
            let fetchResult = PHAsset.fetchAssets(in: collection, options: options)
            let assets = MediasProvider.map(fetchResult: fetchResult, mediaSelectionType: mediaType)
            AlbumMediasLibraryCache.shared.store(models: assets, key: cacheKey)
            DispatchQueue.main.async {
                self.filterAndPublish(assets: assets)
#if os(iOS)
                MediaThumbnailPrefetcher.primeFirstScreenIfNeeded(models: assets)
#endif
            }
        }
    }
}
