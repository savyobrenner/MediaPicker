//
//  AlbumGridSessionStore.swift
//  ExyteMediaPicker
//
//  Keeps grid view models alive while switching Recents / Favorites / Albums
//  so SwiftUI does not rebuild the whole grid and re-fetch thumbnails.
//

import SwiftUI
import Combine

@MainActor
final class AlbumAlbumSession {

    let albumViewModel: AlbumViewModel
    fileprivate let provider: AlbumMediasProvider

    init(
        album: AlbumModel,
        selectionParamsHolder: SelectionParamsHolder,
        filterClosure: MediaPicker.FilterClosure?,
        massFilterClosure: MediaPicker.MassFilterClosure?
    ) {
        provider = AlbumMediasProvider(
            album: album,
            selectionParamsHolder: selectionParamsHolder,
            filterClosure: filterClosure,
            massFilterClosure: massFilterClosure,
            showingLoadingCell: .constant(false)
        )
        let cacheKey = AlbumMediasLibraryCache.shared.cacheKey(
            albumId: album.id,
            mediaType: selectionParamsHolder.mediaType
        )
        albumViewModel = AlbumViewModel(
            mediasProvider: provider,
            mediaTypeForCacheHydration: nil,
            albumMediasCacheKey: cacheKey
        )
    }
}

@MainActor
final class AlbumGridSessionStore {

    private var allPhotosSession: AllPhotosAlbumSession?
    private var albumSessions: [String: AlbumAlbumSession] = [:]

    func allPhotosSession(
        selectionParamsHolder: SelectionParamsHolder,
        filterClosure: MediaPicker.FilterClosure?,
        massFilterClosure: MediaPicker.MassFilterClosure?
    ) -> AllPhotosAlbumSession {
        if let allPhotosSession {
            return allPhotosSession
        }
        if let entry = AllPhotosLibraryCache.shared.entry(for: selectionParamsHolder.mediaType) {
            let session = AllPhotosAlbumSession(
                selectionParamsHolder: selectionParamsHolder,
                filterClosure: filterClosure,
                massFilterClosure: massFilterClosure,
                preloadedEntry: entry
            )
            allPhotosSession = session
            return session
        }
        let session = AllPhotosAlbumSession(
            selectionParamsHolder: selectionParamsHolder,
            filterClosure: filterClosure,
            massFilterClosure: massFilterClosure,
            preloadedEntry: nil
        )
        allPhotosSession = session
        return session
    }

    func albumSession(
        for albumModel: AlbumModel,
        selectionParamsHolder: SelectionParamsHolder,
        filterClosure: MediaPicker.FilterClosure?,
        massFilterClosure: MediaPicker.MassFilterClosure?
    ) -> AlbumAlbumSession {
        if let existing = albumSessions[albumModel.id] {
            return existing
        }
        let session = AlbumAlbumSession(
            album: albumModel,
            selectionParamsHolder: selectionParamsHolder,
            filterClosure: filterClosure,
            massFilterClosure: massFilterClosure
        )
        albumSessions[albumModel.id] = session
        return session
    }

    var openedAlbumSessions: [(id: String, session: AlbumAlbumSession)] {
        albumSessions
            .map { (id: $0.key, session: $0.value) }
            .sorted { $0.id < $1.id }
    }

    func clearAll() {
        allPhotosSession = nil
        albumSessions.removeAll()
    }
}
