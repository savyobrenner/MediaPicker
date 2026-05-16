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
        // Same rationale as AllPhotosProvider: PHAsset.fetchAssets(in:)
        // plus the synchronous mapping loop can block the main thread on
        // big albums. Move the heavy work off the main queue.
        let collection = album.source
        let mediaType = selectionParamsHolder.mediaType
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let options = PHFetchOptions()
            options.sortDescriptors = [
                NSSortDescriptor(key: "modificationDate", ascending: false)
            ]
            let fetchResult = PHAsset.fetchAssets(in: collection, options: options)
            let assets = MediasProvider.map(fetchResult: fetchResult, mediaSelectionType: mediaType)
            DispatchQueue.main.async {
                self.filterAndPublish(assets: assets)
            }
        }
    }
}
