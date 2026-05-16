//
//  Created by Alex.M on 10.06.2022.
//

import Foundation
import Combine
import Photos

final class DefaultAlbumsProvider: AlbumsProviderProtocol {

    private var subject = CurrentValueSubject<[AlbumModel], Never>([])
    private var currentAlbums: [AlbumModel] = []
    private var lastEmittedSignature: String = ""
    var albums: AnyPublisher<[AlbumModel], Never> {
        subject.eraseToAnyPublisher()
    }

    var mediaSelectionType: MediaSelectionType = .photoAndVideo

    /// Fast path for picker open: smart albums only (Favorites, Videos, …) — no user-album scan.
    func reloadSmartAlbumsOnly() {
        PermissionsService.requestPermission { [weak self] in
            self?.reloadSmartAlbumsOnBackground(includeUserAlbums: false)
        }
    }

    func reload() {
        PermissionsService.requestPermission { [weak self] in
            self?.reloadSmartAlbumsOnBackground(includeUserAlbums: true)
        }
    }

    private func reloadSmartAlbumsOnBackground(includeUserAlbums: Bool) {
        let mediaType = mediaSelectionType
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let smart = self.fetchSmartAlbums()
            let user: [AlbumModel]
            if includeUserAlbums {
                user = self.fetchUserAlbums()
            } else {
                user = []
            }
            let combined = smart + user
            self.publishOnMain(combined, mediaType: mediaType)
        }
    }

    private func publishOnMain(_ combined: [AlbumModel], mediaType: MediaSelectionType) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.mediaSelectionType == mediaType else { return }
            let signature = "\(mediaType)|" + combined.map(\.id).joined(separator: ",")
            if signature != self.lastEmittedSignature {
                self.lastEmittedSignature = signature
                self.currentAlbums = combined
                self.subject.send(combined)
            }
        }
    }
}

private extension DefaultAlbumsProvider {

    func fetchSmartAlbums() -> [AlbumModel] {
        SmartAlbumKind.allCases
            .filter { $0.isAvailable(for: mediaSelectionType) }
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { buildSmartAlbum(kind: $0) }
    }

    func buildSmartAlbum(kind: SmartAlbumKind) -> AlbumModel? {
        let result = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: kind.subtype,
            options: nil
        )
        guard let collection = result.firstObject else { return nil }

        let assets = PHAsset.fetchAssets(in: collection, options: assetFetchOptions(limit: 1))

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
            let assets = PHAsset.fetchAssets(in: collection, options: self.assetFetchOptions(limit: 1))
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
