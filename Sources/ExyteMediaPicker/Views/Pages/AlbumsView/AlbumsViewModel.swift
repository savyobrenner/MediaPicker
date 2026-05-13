//
//  Created by Alex.M on 07.06.2022.
//

import Foundation
import Combine

@MainActor
final class AlbumsViewModel: ObservableObject {

    @Published var smartAlbums: [AlbumModel] = []
    @Published var userAlbums: [AlbumModel] = []
    @Published var isLoading: Bool = false
    
    let albumsProvider: AlbumsProviderProtocol

    private var albumsCancellable: AnyCancellable?
    
    init(albumsProvider: AlbumsProviderProtocol) {
        self.albumsProvider = albumsProvider
    }
    
    func onStart() {
        isLoading = true
        
        albumsCancellable = albumsProvider.albums
            .receive(on: DispatchQueue.main)
            .sink { [weak self] albums in
                guard let self = self else { return }
                self.smartAlbums = albums.filter { $0.kind != nil }
                self.userAlbums  = albums.filter { $0.kind == nil }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.isLoading = false
                }
            }
        
        albumsProvider.reload()
    }
    
    func onStop() {
        albumsCancellable = nil
    }
}
