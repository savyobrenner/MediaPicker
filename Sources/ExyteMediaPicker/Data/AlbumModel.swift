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
    /// `nil` means user-created album. Otherwise it's a system smart album
    /// (Favorites, Videos, Selfies, etc.) the UI may want to render
    /// with the matching native icon.
    public let kind: SmartAlbumKind?

    public init(id: String,
                title: String?,
                quantity: String?,
                preview: PHAsset?,
                kind: SmartAlbumKind? = nil) {
        self.id = id
        self.title = title
        self.quantity = quantity
        self.preview = preview
        self.kind = kind
    }
}

struct AlbumModel {
    let preview: AssetMediaModel?
    let source: PHAssetCollection
    let mediaType: MediaSelectionType
    /// When non-nil, this album corresponds to one of the iOS native smart
    /// albums (Recents, Favorites, Videos, Selfies, ...). Used by the UI to
    /// render the matching SF Symbol and localized title.
    let kind: SmartAlbumKind?
}

extension AlbumModel: Identifiable {
    public var id: String {
        source.localIdentifier
    }

    public var title: String? {
        kind?.localizedTitle ?? source.localizedTitle
    }
    
    var assetsQuantity: String? {
        let fetchOptions = PHFetchOptions()

        switch mediaType {
        case .photo:
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        case .video:
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        case .photoAndVideo:
            break
        }

        let fetchResult = PHAsset.fetchAssets(in: source, options: fetchOptions)
        return "\(fetchResult.count)"
    }
}

extension AlbumModel: Equatable {}

extension AlbumModel {
    func toAlbum() -> Album {
        Album(id: id, title: title, quantity: assetsQuantity, preview: preview?.asset, kind: kind)
    }
}
