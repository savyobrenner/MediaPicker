//
//  Created by Alex.M on 09.06.2022.
//

import Foundation
import Photos
import Combine
import SwiftUI

final class AllPhotosProvider: BaseMediasProvider {

    override func reload() {
        PermissionsService.requestPermission { [weak self] in
            self?.reloadInternal()
        }
    }

    func reloadInternal() {
        // Fetching and mapping PHAssets is O(N) over the user's whole
        // library; on large libraries this can block the main thread for
        // a noticeable amount of time. Run it on a background queue and
        // hop back to the main thread only to publish the results.
        let mediaType = selectionParamsHolder.mediaType
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let options = PHFetchOptions()
            options.sortDescriptors = [
                NSSortDescriptor(key: "modificationDate", ascending: false)
            ]
            let fetchResult = PHAsset.fetchAssets(with: options)
            let assets = MediasProvider.map(fetchResult: fetchResult, mediaSelectionType: mediaType)
            DispatchQueue.main.async {
                self.filterAndPublish(assets: assets)
            }
        }
    }
}
