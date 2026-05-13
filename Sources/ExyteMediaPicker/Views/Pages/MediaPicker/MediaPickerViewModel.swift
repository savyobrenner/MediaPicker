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
}
