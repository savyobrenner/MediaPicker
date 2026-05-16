//
//  AllPhotosAlbumSession.swift
//  ExyteMediaPicker
//
//  One provider + one AlbumViewModel for the whole picker presentation.
//  Avoids recreating them on every SwiftUI body pass (which caused reload + spinner every open).
//

import SwiftUI
import Combine

@MainActor
final class AllPhotosAlbumSession: ObservableObject {

    @Published var showingLoadingCell = false

    let albumViewModel: AlbumViewModel
    private let provider: AllPhotosProvider
    private let loadingFlag = LoadingFlag()
    private var loadingCancellable: AnyCancellable?
    private var mediaTypeCancellable: AnyCancellable?

    init(
        selectionParamsHolder: SelectionParamsHolder,
        filterClosure: MediaPicker.FilterClosure?,
        massFilterClosure: MediaPicker.MassFilterClosure?
    ) {
        provider = AllPhotosProvider(
            selectionParamsHolder: selectionParamsHolder,
            filterClosure: filterClosure,
            massFilterClosure: massFilterClosure,
            showingLoadingCell: loadingFlag.binding
        )

        albumViewModel = AlbumViewModel(
            mediasProvider: provider,
            mediaTypeForCacheHydration: selectionParamsHolder.mediaType
        )

        loadingCancellable = loadingFlag.$value
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.showingLoadingCell = $0 }

        mediaTypeCancellable = selectionParamsHolder.$mediaType
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] mediaType in
                self?.albumViewModel.prepareForMediaTypeChange(mediaType)
                self?.provider.reload()
            }
    }
}

/// Bridges filter loading flag from `BaseMediasProvider` into the session.
private final class LoadingFlag: ObservableObject {
    @Published var value = false

    var binding: Binding<Bool> {
        Binding(
            get: { self.value },
            set: { self.value = $0 }
        )
    }
}

/// Host view — session is owned by `AlbumGridSessionStore`, not recreated per tab switch.
struct AllPhotosAlbumRoute: View {

    @ObservedObject var session: AllPhotosAlbumSession

    @Binding var isInFullscreen: Bool
    @Binding var currentFullscreenMedia: Media?
    let selectionParamsHolder: SelectionParamsHolder
    var shouldDismiss: () -> Void

    var body: some View {
        AlbumView(
            viewModel: session.albumViewModel,
            isInFullscreen: $isInFullscreen,
            currentFullscreenMedia: $currentFullscreenMedia,
            shouldShowLoadingCell: session.showingLoadingCell,
            selectionParamsHolder: selectionParamsHolder,
            shouldDismiss: shouldDismiss
        )
    }
}
