//
//  Created by Alex.M on 10.06.2022.
//

import Foundation
import Combine
import Photos

final class DefaultAlbumsProvider: AlbumsProviderProtocol {
    
    private var subject = CurrentValueSubject<[AlbumModel], Never>([])
    private var currentAlbums: [AlbumModel] = []
    private var albumsCancellable: AnyCancellable?
    private var permissionCancellable: AnyCancellable?
    
    var albums: AnyPublisher<[AlbumModel], Never> {
        subject.eraseToAnyPublisher()
    }
    
    var mediaSelectionType: MediaSelectionType = .photoAndVideo
    
    func reload() {
        PermissionsService.requestPermission { [ weak self] in
            self?.reloadInternal()
        }
    }
    
    func reloadInternal() {
        albumsCancellable = [PHAssetCollectionType.smartAlbum, .smartAlbum]
            .publisher
            .map { fetchAlbums(type: $0) }
            .scan([], +)
            .map { [weak self] allAlbums in
                let uniqueAlbums = self?.removeDuplicateAlbums(allAlbums) ?? []
                return self?.customSortAlbums(uniqueAlbums) ?? []
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newAlbums in
                guard let self = self else { return }
                if !self.currentAlbums.elementsEqual(newAlbums, by: { $0.source.localIdentifier == $1.source.localIdentifier }) {
                    self.currentAlbums = newAlbums
                    self.subject.send(newAlbums)
                }
            }
    }
    
    private func removeDuplicateAlbums(_ albums: [AlbumModel]) -> [AlbumModel] {
        var uniqueAlbums = [String: AlbumModel]()
        for album in albums {
            uniqueAlbums[album.source.localizedTitle ?? ""] = album
        }
        return Array(uniqueAlbums.values)
    }
    
    private func customSortAlbums(_ albums: [AlbumModel]) -> [AlbumModel] {
        let favoritesTitles = ["Favoritos", "Favorites"]
        let recentTitles = ["Recentes", "Recents"]

        let specialAlbums = albums.filter {
            favoritesTitles.contains($0.source.localizedTitle ?? "") || recentTitles.contains($0.source.localizedTitle ?? "")
        }
        
        let otherAlbums = albums.filter {
            !favoritesTitles.contains($0.source.localizedTitle ?? "") && !recentTitles.contains($0.source.localizedTitle ?? "")
        }
        .sorted { $0.source.localizedTitle ?? "" < $1.source.localizedTitle ?? "" }

        return specialAlbums + otherAlbums
    }
}

private extension DefaultAlbumsProvider {
    
    func fetchAlbums(type: PHAssetCollectionType) -> [AlbumModel] {
        let options = PHFetchOptions()
        options.includeAssetSourceTypes = [.typeUserLibrary, .typeiTunesSynced, .typeCloudShared]
        options.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
        
        let collections = PHAssetCollection.fetchAssetCollections(
            with: type,
            subtype: .any,
            options: options
        )
        
        if collections.count == 0 {
            return []
        }
        
        var albums: [AlbumModel] = []
        
        collections.enumerateObjects { (collection, index, stop) in
            let options = PHFetchOptions()
            
            switch self.mediaSelectionType {
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
            options.fetchLimit = 1
            let fetchResult = PHAsset.fetchAssets(in: collection, options: options)
            if fetchResult.count == 0 {
                return
            }
            
            let preview = MediasProvider.map(fetchResult: fetchResult, mediaSelectionType: self.mediaSelectionType).first
            let album = AlbumModel(preview: preview, source: collection, mediaType: self.mediaSelectionType)
            albums.append(album)
        }
        
        return albums
    }
}
