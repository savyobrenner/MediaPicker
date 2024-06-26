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
        PermissionsService.requestPermission { [ weak self] in
            self?.reloadInternal()
        }
    }

    func reloadInternal() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [
            NSSortDescriptor(key: "modificationDate", ascending: false)
        ]
        let fetchResult = PHAsset.fetchAssets(in: album.source, options: fetchOptions)
        if fetchResult.count == 0 {
            assetMediaModelsPublisher.send([])
        }

        let assets = MediasProvider.map(fetchResult: fetchResult, mediaSelectionType: selectionParamsHolder.mediaType)
        filterAndPublish(assets: assets)
    }
}
