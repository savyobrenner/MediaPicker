//
//  AlbumSelectionView.swift
//  
//
//  Created by Alisa Mylnikova on 08.02.2023.
//

import SwiftUI

public struct AlbumSelectionView: View {

    @ObservedObject var viewModel: MediaPickerViewModel

    @Binding var showingCamera: Bool
    @Binding var isInFullscreen: Bool
    @Binding var currentFullscreenMedia: Media?

    let showingLiveCameraCell: Bool
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
                showingCamera: $showingCamera,
                isInFullscreen: $isInFullscreen,
                currentFullscreenMedia: $currentFullscreenMedia,
                shouldShowCamera: showingLiveCameraCell,
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
                showingCamera: $showingCamera,
                currentFullscreenMedia: $currentFullscreenMedia,
                selectionParamsHolder: selectionParamsHolder,
                filterClosure: filterClosure,
                massFilterClosure: massFilterClosure
            )
            .onAppear {
                viewModel.defaultAlbumsProvider.mediaSelectionType = selectionParamsHolder.mediaType
            }
        case .album(let album):
            if let albumModel = viewModel.getAlbumModel(album) {
                AlbumView(
                    viewModel: AlbumViewModel(
                        mediasProvider: AlbumMediasProvider(album: albumModel, selectionParamsHolder: selectionParamsHolder, filterClosure: filterClosure, massFilterClosure: massFilterClosure, showingLoadingCell: $showingLoadingCell)
                    ),
                    showingCamera: $showingCamera,
                    isInFullscreen: $isInFullscreen,
                    currentFullscreenMedia: $currentFullscreenMedia,
                    shouldShowCamera: false,
                    shouldShowLoadingCell: showingLoadingCell,
                    selectionParamsHolder: selectionParamsHolder,
                    shouldDismiss: shouldDismiss
                )
                .id(album.id)
            }
        default:
            EmptyView()
        }
    }
}

public struct ModeSwitcher: View {
    @Binding var selection: Int
    var mediaTitle: String

    public var body: some View {
        HStack {
            ModeSwitcherButton(title: mediaTitle, isSelected: selection == 0) {
                self.selection = 0
            }
            ModeSwitcherButton(title: "Albums", isSelected: selection == 1) {
                self.selection = 1
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width / 2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(uiColor: UIColor(red: 0.949, green: 0.698, blue: 0.188, alpha: 1)), lineWidth: 1)
                .background(Color.clear)
        )
    }
}

struct ModeSwitcherButton: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .foregroundColor(isSelected ? .black : Color(uiColor: UIColor(red: 0.949, green: 0.698, blue: 0.188, alpha: 1)))
                .padding()
                .background(isSelected ? Color(uiColor: UIColor(red: 0.949, green: 0.698, blue: 0.188, alpha: 1)) : Color.clear)
                .cornerRadius(8)
        }
    }
}
