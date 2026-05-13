//
//  AlbumSelectionView.swift
//  
//
//  Created by Alisa Mylnikova on 08.02.2023.
//

import SwiftUI

public struct AlbumSelectionView: View {

    @ObservedObject var viewModel: MediaPickerViewModel

    @Binding var isInFullscreen: Bool
    @Binding var currentFullscreenMedia: Media?

    let selectionParamsHolder: SelectionParamsHolder
    let filterClosure: MediaPicker.FilterClosure?
    let massFilterClosure: MediaPicker.MassFilterClosure?
    var shouldDismiss: ()->()

    @State private var showingLoadingCell = false

    public var body: some View {
        switch viewModel.internalPickerMode {
        case .photos:
            AlbumView(
                viewModel: AlbumViewModel(
                    mediasProvider: AllPhotosProvider(selectionParamsHolder: selectionParamsHolder, filterClosure: filterClosure, massFilterClosure: massFilterClosure, showingLoadingCell: $showingLoadingCell)
                ),
                isInFullscreen: $isInFullscreen,
                currentFullscreenMedia: $currentFullscreenMedia,
                shouldShowLoadingCell: showingLoadingCell,
                selectionParamsHolder: selectionParamsHolder,
                shouldDismiss: shouldDismiss
            )
        case .albums:
            AlbumsView(
                viewModel: AlbumsViewModel(
                    albumsProvider: viewModel.defaultAlbumsProvider
                ),
                mediaPickerViewModel: viewModel,
                currentFullscreenMedia: $currentFullscreenMedia,
                selectionParamsHolder: selectionParamsHolder,
                filterClosure: filterClosure,
                massFilterClosure: massFilterClosure
            )
        case .album(let album):
            if let albumModel = viewModel.getAlbumModel(album) {
                AlbumView(
                    viewModel: AlbumViewModel(
                        mediasProvider: AlbumMediasProvider(album: albumModel, selectionParamsHolder: selectionParamsHolder, filterClosure: filterClosure, massFilterClosure: massFilterClosure, showingLoadingCell: $showingLoadingCell)
                    ),
                    isInFullscreen: $isInFullscreen,
                    currentFullscreenMedia: $currentFullscreenMedia,
                    shouldShowLoadingCell: showingLoadingCell,
                    selectionParamsHolder: selectionParamsHolder,
                    shouldDismiss: shouldDismiss
                )
                .id(album.id)
            }
        }
    }
}

/// Native-style title view used in the picker nav bar. Renders the current
/// album/mode as "TITLE ▾" and, on tap, opens a Menu listing every
/// available album (mirroring the iOS 26 Photos title dropdown).
public struct AlbumTitleView: View {

    @ObservedObject var viewModel: MediaPickerViewModel
    let mediaTitle: String
    @EnvironmentObject private var selectionParamsHolder: SelectionParamsHolder

    /// Albums shown in the title dropdown, respecting the current
    /// `mediaSelectionType` (e.g. no "Videos" smart album when only
    /// importing photos).
    private var menuAlbums: [AlbumModel] {
        viewModel.albums.filter { album in
            guard let kind = album.kind else { return true }
            return kind.isAvailable(for: selectionParamsHolder.mediaType)
        }
    }

    public var body: some View {
        Menu {
            Button(action: { viewModel.setPickerMode(.photos) }) {
                Label(mediaTitle, systemImage: "photo.on.rectangle")
            }
            Button(action: { viewModel.setPickerMode(.albums) }) {
                Label(albumsLabel, systemImage: "rectangle.stack")
            }
            
            if !menuAlbums.isEmpty {
                Divider()
                ForEach(menuAlbums) { albumModel in
                    Button {
                        viewModel.setPickerMode(.album(albumModel.toAlbum()))
                    } label: {
                        Label(
                            albumModel.title ?? "",
                            systemImage: albumModel.kind?.systemImageName ?? "folder"
                        )
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(currentTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
    }
    
    private var currentTitle: String {
        switch viewModel.internalPickerMode {
        case .photos:
            return mediaTitle
        case .albums:
            return albumsLabel
        case .album(let album):
            return album.title ?? mediaTitle
        }
    }
    
    private var albumsLabel: String {
        let isPortuguese = Locale.preferredLanguages.first?.hasPrefix("pt") ?? false
        return isPortuguese ? "Álbuns" : "Albums"
    }
}
