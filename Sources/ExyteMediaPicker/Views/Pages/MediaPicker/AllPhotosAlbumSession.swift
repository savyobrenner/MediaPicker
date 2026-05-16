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

  deinit {
    MediaPickerLifecycle.releaseResourcesAfterPickerDismissed()
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

/// Host view so `AllPhotosAlbumSession` is created exactly once per picker open.
struct AllPhotosAlbumRoute: View {

  @StateObject private var session: AllPhotosAlbumSession

  @Binding var isInFullscreen: Bool
  @Binding var currentFullscreenMedia: Media?
  let selectionParamsHolder: SelectionParamsHolder
  var shouldDismiss: () -> Void

  init(
    selectionParamsHolder: SelectionParamsHolder,
    filterClosure: MediaPicker.FilterClosure?,
    massFilterClosure: MediaPicker.MassFilterClosure?,
    isInFullscreen: Binding<Bool>,
    currentFullscreenMedia: Binding<Media?>,
    shouldDismiss: @escaping () -> Void
  ) {
    _session = StateObject(
      wrappedValue: AllPhotosAlbumSession(
        selectionParamsHolder: selectionParamsHolder,
        filterClosure: filterClosure,
        massFilterClosure: massFilterClosure
      )
    )
    _isInFullscreen = isInFullscreen
    _currentFullscreenMedia = currentFullscreenMedia
    self.selectionParamsHolder = selectionParamsHolder
    self.shouldDismiss = shouldDismiss
  }

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
