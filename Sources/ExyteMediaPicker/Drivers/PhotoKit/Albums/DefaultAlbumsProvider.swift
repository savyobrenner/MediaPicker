//
//  Created by Alex.M on 10.06.2022.
//

import Foundation
import Combine
import Photos

/// Fetches the same set of albums that the iOS 26 Photos app exposes in the
/// "Albums" tab: smart albums (Recents, Favorites, Videos, Selfies, ...) plus
/// every user-created album. Smart albums carry a `SmartAlbumKind` so the UI
/// can render the matching native SF Symbol and ordering.
final class DefaultAlbumsProvider: AlbumsProviderProtocol {
    
    private var subject = CurrentValueSubject<[AlbumModel], Never>([])
    private var currentAlbums: [AlbumModel] = []
    
    var albums: AnyPublisher<[AlbumModel], Never> {
        subject.eraseToAnyPublisher()
    }
    
    var mediaSelectionType: MediaSelectionType = .photoAndVideo
    
    func reload() {
        PermissionsService.requestPermission { [weak self] in
            self?.reloadInternal()
        }
    }
    
    private func reloadInternal() {
        let smart = fetchSmartAlbums()
        let user = fetchUserAlbums()
        let combined = smart + user
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.currentAlbums.elementsEqual(combined, by: { $0.id == $1.id }) {
                self.currentAlbums = combined
                self.subject.send(combined)
            }
        }
    }
}

private extension DefaultAlbumsProvider {

    /// Fetches every native smart album that is relevant for the current
    /// `mediaSelectionType`. Returned in the same display order as the
    /// Photos app sidebar in iOS 26.
    func fetchSmartAlbums() -> [AlbumModel] {
        SmartAlbumKind.allCases
            .filter { $0.isAvailable(for: mediaSelectionType) }
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { buildSmartAlbum(kind: $0) }
    }
    
    func buildSmartAlbum(kind: SmartAlbumKind) -> AlbumModel? {
        let options = PHFetchOptions()
        let result = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: kind.subtype,
            options: options
        )
        guard let collection = result.firstObject else { return nil }
        
        let assetOptions = assetFetchOptions(limit: 1)
        let assets = PHAsset.fetchAssets(in: collection, options: assetOptions)
        
        // Hide empty smart albums (Apple Photos hides them too).
        // The "All Photos" album is always shown even if empty.
        if assets.count == 0 && kind != .allPhotos {
            return nil
        }
        
        let preview = MediasProvider.map(
            fetchResult: assets,
            mediaSelectionType: mediaSelectionType
        ).first
        
        return AlbumModel(
            preview: preview,
            source: collection,
            mediaType: mediaSelectionType,
            kind: kind
        )
    }
    
    /// User-created albums. Sorted alphabetically (matching Photos app).
    func fetchUserAlbums() -> [AlbumModel] {
        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "localizedTitle", ascending: true)
        ]
        
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .any,
            options: options
        )
        
        var albums: [AlbumModel] = []
        collections.enumerateObjects { collection, _, _ in
            let assetOptions = self.assetFetchOptions(limit: 1)
            let assets = PHAsset.fetchAssets(in: collection, options: assetOptions)
            // Hide empty user albums (mirrors native Photos behaviour).
            if assets.count == 0 { return }
            
            let preview = MediasProvider.map(
                fetchResult: assets,
                mediaSelectionType: self.mediaSelectionType
            ).first
            
            albums.append(
                AlbumModel(
                    preview: preview,
                    source: collection,
                    mediaType: self.mediaSelectionType,
                    kind: nil
                )
            )
        }
        return albums
    }
    
    func assetFetchOptions(limit: Int) -> PHFetchOptions {
        let options = PHFetchOptions()
        switch mediaSelectionType {
        case .photo:
            options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        case .video:
            options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        case .photoAndVideo:
            break
        }
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        options.fetchLimit = limit
        return options
    }
}
