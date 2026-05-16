//
//  AlbumSelectionView.swift
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

  private var isPhotosMode: Bool {
    if case .photos = viewModel.internalPickerMode { return true }
    return false
  }

  private var isAlbumsListMode: Bool {
    if case .albums = viewModel.internalPickerMode { return true }
    return false
  }

    public var body: some View {
        VStack(spacing: 0) {
            if selectionParamsHolder.showsAlbumQuickAccessBar, !isInFullscreen {
                AlbumQuickAccessBar(viewModel: viewModel)
                Divider()
                    .opacity(0.35)
            }

            ZStack {
                allPhotosLayer
                albumsListLayer
                openedAlbumLayers
            }
            .onChange(of: viewModel.internalPickerMode) { _ in
                ensureActiveAlbumSessionIfNeeded()
            }
            .onAppear {
                ensureActiveAlbumSessionIfNeeded()
            }
        }
    }

    private var allPhotosLayer: some View {
        let session = viewModel.albumGridSessionStore.allPhotosSession(
            selectionParamsHolder: selectionParamsHolder,
            filterClosure: filterClosure,
            massFilterClosure: massFilterClosure
        )
        return AllPhotosAlbumRoute(
            session: session,
            isInFullscreen: $isInFullscreen,
            currentFullscreenMedia: $currentFullscreenMedia,
            selectionParamsHolder: selectionParamsHolder,
            shouldDismiss: shouldDismiss
        )
        .opacity(isPhotosMode ? 1 : 0)
        .allowsHitTesting(isPhotosMode)
        .accessibilityHidden(!isPhotosMode)
    }

    @ViewBuilder
    private var albumsListLayer: some View {
        if isAlbumsListMode {
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
        }
    }

    private func ensureActiveAlbumSessionIfNeeded() {
        guard case .album(let album) = viewModel.internalPickerMode,
              let albumModel = viewModel.getAlbumModel(album) else { return }
        _ = viewModel.albumGridSessionStore.albumSession(
            for: albumModel,
            selectionParamsHolder: selectionParamsHolder,
            filterClosure: filterClosure,
            massFilterClosure: massFilterClosure
        )
    }

    @ViewBuilder
    private var openedAlbumLayers: some View {
        let activeAlbumId: String? = {
            if case .album(let album) = viewModel.internalPickerMode { return album.id }
            return nil
        }()

        ForEach(viewModel.albumGridSessionStore.openedAlbumSessions, id: \.id) { entry in
            let isActive = entry.id == activeAlbumId
            AlbumView(
                viewModel: entry.session.albumViewModel,
                isInFullscreen: $isInFullscreen,
                currentFullscreenMedia: $currentFullscreenMedia,
                shouldShowLoadingCell: false,
                selectionParamsHolder: selectionParamsHolder,
                shouldDismiss: shouldDismiss
            )
            .opacity(isActive ? 1 : 0)
            .allowsHitTesting(isActive)
            .accessibilityHidden(!isActive)
        }
    }
}

/// Native-style title view used in the picker nav bar.
public struct AlbumTitleView: View {

    @ObservedObject var viewModel: MediaPickerViewModel
    let mediaTitle: String
    @EnvironmentObject private var selectionParamsHolder: SelectionParamsHolder

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
