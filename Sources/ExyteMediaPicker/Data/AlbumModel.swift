//
//  Created by Alex.M on 27.05.2022.
//

import Foundation
import Photos

public struct Album: Identifiable {
    public let id: String
    public let title: String?
    public let quantity: String?
    public let preview: PHAsset?
}

struct AlbumModel {
    let preview: AssetMediaModel?
    let source: PHAssetCollection
}

extension AlbumModel: Identifiable {
    public var id: String {
        source.localIdentifier
    }

    public var title: String? {
        source.localizedTitle
    }
}

extension AlbumModel: Equatable {}

extension AlbumModel {
    func fetchMediaCount(ofType mediaType: PHAssetMediaType) -> Int {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType = %d", mediaType.rawValue)

        let assets = PHAsset.fetchAssets(in: source, options: options)
        return assets.count
    }

    func toAlbum(for mediaType: PHAssetMediaType) -> Album {
        let count = fetchMediaCount(ofType: mediaType)
        return Album(id: id, title: title, quantity: "(\(count))", preview: preview?.asset)
    }
}
