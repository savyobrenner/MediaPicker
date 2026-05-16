//
// Created by Alex.M on 07.06.2022.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class MediaPickerViewModel: ObservableObject {

    @Published private(set) var internalPickerMode: MediaPickerMode = .photos
    @Published private(set) var albums: [AlbumModel] = []

    var shouldUpdatePickerMode: (MediaPickerMode)->() = {_ in}

    let defaultAlbumsProvider = DefaultAlbumsProvider()
    let albumGridSessionStore = AlbumGridSessionStore()
    private let watcher = PhotoLibraryChangePermissionWatcher()
    private var albumsCancellable: AnyCancellable?
    
    func onStart() {
        defaultAlbumsProvider.reload()
        albumsCancellable = defaultAlbumsProvider.albums.sink { [weak self] albums in
            self?.albums = albums
        }
    }

    func getAlbumModel(_ album: Album) -> AlbumModel? {
        albums.filter { $0.id == album.id }.first
    }

    func setPickerMode(_ mode: MediaPickerMode) {
        internalPickerMode = mode
        shouldUpdatePickerMode(mode)
    }

    func albumModel(kind: SmartAlbumKind) -> AlbumModel? {
        albums.first { $0.kind == kind }
    }

    func quickAccessItems(for mediaType: MediaSelectionType) -> [AlbumQuickAccessItem] {
        var items: [AlbumQuickAccessItem] = [.recents]

        for kind in Self.preferredShortcutKinds(for: mediaType) {
            guard kind.isAvailable(for: mediaType), albumModel(kind: kind) != nil else { continue }
            items.append(.smartAlbum(kind))
        }

        items.append(.browseAlbums)
        return items
    }

    func isQuickAccessSelected(_ item: AlbumQuickAccessItem, mode: MediaPickerMode) -> Bool {
        switch (item, mode) {
        case (.recents, .photos):
            return true
        case (.browseAlbums, .albums):
            return true
        case (.smartAlbum(let kind), .album(let album)):
            return album.kind == kind
        default:
            return false
        }
    }

    func applyQuickAccess(_ item: AlbumQuickAccessItem) {
        switch item {
        case .recents:
            setPickerMode(.photos)
        case .browseAlbums:
            setPickerMode(.albums)
        case .smartAlbum(let kind):
            guard let model = albumModel(kind: kind) else { return }
            setPickerMode(.album(model.toAlbum()))
        }
    }

    func clearAlbumGridSessions() {
        albumGridSessionStore.clearAll()
    }

    private static func preferredShortcutKinds(for mediaType: MediaSelectionType) -> [SmartAlbumKind] {
        switch mediaType {
        case .photo:
            return [.favorites, .screenshots, .livePhotos, .selfies]
        case .video:
            return [.favorites, .videos]
        case .photoAndVideo:
            return [.favorites, .videos, .screenshots, .livePhotos]
        }
    }
}
