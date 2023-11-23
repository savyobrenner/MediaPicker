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
    let mediaType: MediaSelectionType
}

extension AlbumModel: Identifiable {
    public var id: String {
        source.localIdentifier
    }

    public var title: String? {
        source.localizedTitle
    }
    
    var assetsQuantity: String? {
        let fetchOptions = PHFetchOptions()

        switch mediaType {
        case .photo:
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        case .video:
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        case .photoAndVideo:
            // Sem predicado para ambos os tipos
            break
        }

        let fetchResult = PHAsset.fetchAssets(in: source, options: fetchOptions)
        return "(\(fetchResult.count))"
    }
}

extension AlbumModel: Equatable {}

extension AlbumModel {
    func toAlbum() -> Album {
        Album(id: id, title: title, quantity: assetsQuantity, preview: preview?.asset)
    }
}
