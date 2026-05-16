//
//  Created by Alex.M on 26.05.2022.
//

import SwiftUI
import Combine

public struct MediaPicker<AlbumSelectionContent: View>: View {

    /// Builder closure that lets the caller customize the layout around
    /// the album content. Arguments:
    /// - title view (`AlbumTitleView`): native-style album switcher with a chevron dropdown
    /// - album content (`AlbumSelectionView`)
    /// - is in fullscreen photo details mode
    public typealias AlbumSelectionClosure = ((AlbumTitleView, AlbumSelectionView, Bool) -> AlbumSelectionContent)

    public typealias FilterClosure = (Media) async -> Media?
    public typealias MassFilterClosure = ([Media]) async -> [Media]

    // MARK: - Parameters

    @Binding private var isPresented: Bool
    private let onChange: MediaPickerCompletionClosure

    // MARK: - View builders

    private var albumSelectionBuilder: AlbumSelectionClosure? = nil
    private var mediaTitle = "Photos"

    // MARK: - Customization

    @Binding private var albums: [Album]
    @Binding private var currentFullscreenMediaBinding: Media?

    private var pickerMode: Binding<MediaPickerMode>?
    private var orientationHandler: MediaPickerOrientationHandler = {_ in}
    private var filterClosure: FilterClosure?
    private var massFilterClosure: MassFilterClosure?
    private var selectionParamsHolder = SelectionParamsHolder()

    // MARK: - Inner values

    @Environment(\.mediaPickerTheme) private var theme

    @StateObject private var viewModel = MediaPickerViewModel()
    @StateObject private var selectionService = SelectionService()
    @StateObject private var permissionService = PermissionsService()

    @State private var isInFullscreen: Bool = false
    @State private var currentFullscreenMedia: Media?

    @State private var internalPickerMode: MediaPickerMode = .photos

    // MARK: - Object life cycle

    public init(isPresented: Binding<Bool>,
                onChange: @escaping MediaPickerCompletionClosure,
                mediaTitle: String = "Photos",
                albumSelectionBuilder: AlbumSelectionClosure? = nil) {

        self._isPresented = isPresented
        self._albums = .constant([])
        self._currentFullscreenMediaBinding = .constant(nil)

        self.onChange = onChange
        self.albumSelectionBuilder = albumSelectionBuilder
        self.mediaTitle = mediaTitle

        MediaPickerWarmup.installAutomaticWarmupWhenLibraryAuthorized()
    }

    public var body: some View {
        albumSelectionContainer
            .background(theme.main.albumSelectionBackground.ignoresSafeArea())
            .environmentObject(selectionService)
            .environmentObject(permissionService)
            .environmentObject(selectionParamsHolder)
            .onAppear {
                permissionService.askLibraryPermissionIfNeeded()

                selectionService.onChange = onChange
                selectionService.mediaSelectionLimit = selectionParamsHolder.selectionLimit

                viewModel.defaultAlbumsProvider.mediaSelectionType = selectionParamsHolder.mediaType
                viewModel.shouldUpdatePickerMode = { mode in
                    pickerMode?.wrappedValue = mode
                }
                viewModel.onStart()
                MediaPickerWarmup.prepareLibraryCacheIfNeeded(mediaType: selectionParamsHolder.mediaType)
            }
            .onChange(of: viewModel.albums) {
                self.albums = $0.map { $0.toAlbum() }
            }
            .onChange(of: pickerMode?.wrappedValue) { mode in
                if let mode = mode {
                    viewModel.setPickerMode(mode)
                }
            }
            .onChange(of: viewModel.internalPickerMode) { newValue in
                internalPickerMode = newValue
            }
            .onChange(of: currentFullscreenMedia) { currentFullscreenMedia in
                _currentFullscreenMediaBinding.wrappedValue = currentFullscreenMedia
            }
            .onAppear {
                if let mode = pickerMode?.wrappedValue {
                    viewModel.setPickerMode(mode)
                }
            }
            .onReceive(selectionParamsHolder.$mediaType) { newValue in
                viewModel.defaultAlbumsProvider.mediaSelectionType = newValue
                viewModel.defaultAlbumsProvider.reload()
            }
    }

    @ViewBuilder
    var albumSelectionContainer: some View {
        let albumSelectionView = AlbumSelectionView(
            viewModel: viewModel,
            isInFullscreen: $isInFullscreen,
            currentFullscreenMedia: $currentFullscreenMedia,
            selectionParamsHolder: selectionParamsHolder,
            filterClosure: filterClosure,
            massFilterClosure: massFilterClosure
        ) {
            // has media limit of 1, and it's been selected
            isPresented = false
        }

        if let albumSelectionBuilder = albumSelectionBuilder {
            albumSelectionBuilder(
                AlbumTitleView(viewModel: viewModel, mediaTitle: mediaTitle),
                albumSelectionView,
                isInFullscreen
            )
        } else {
            VStack(spacing: 0) {
                if !isInFullscreen {
                    defaultHeaderView
                }
                albumSelectionView
            }
        }
    }

    /// Native-style nav bar inspired by the iOS 26 Photos picker:
    /// - Leading: Cancelar / Cancel
    /// - Center: AlbumTitleView (current title + chevron dropdown menu)
    /// - Trailing: Adicionar (N) / Add (N), disabled when N == 0
    var defaultHeaderView: some View {
        HStack {
            Button(localized("Cancelar", "Cancel")) {
                selectionService.removeAll()
                isPresented = false
            }
            .font(.system(size: 17))
            .foregroundColor(.accentColor)
            .padding(.leading, 16)

            Spacer()

            AlbumTitleView(viewModel: viewModel, mediaTitle: mediaTitle)

            Spacer()

            Button {
                if selectionService.selected.isEmpty, let current = currentFullscreenMedia {
                    onChange([current])
                } else {
                    onChange(selectionService.mapToMedia())
                }
                isPresented = false
            } label: {
                Text(addLabel)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(addEnabled ? .accentColor : .secondary)
            }
            .disabled(!addEnabled)
            .padding(.trailing, 16)
        }
        .frame(height: 44)
        .background(.bar)
    }
    
    private var addEnabled: Bool {
        !selectionService.selected.isEmpty || currentFullscreenMedia != nil
    }
    
    private var addLabel: String {
        let count = selectionService.selected.count
        let baseAdd = localized("Adicionar", "Add")
        if count > 0 {
            return "\(baseAdd) (\(count))"
        }
        return baseAdd
    }
    
    private func localized(_ ptBR: String, _ enUS: String) -> String {
        let isPortuguese = Locale.preferredLanguages.first?.hasPrefix("pt") ?? false
        return isPortuguese ? ptBR : enUS
    }
}

// MARK: - Customization

public extension MediaPicker {

    func mediaSelectionType(_ type: MediaSelectionType) -> MediaPicker {
        selectionParamsHolder.mediaType = type
        return self
    }

    func mediaSelectionStyle(_ style: MediaSelectionStyle) -> MediaPicker {
        selectionParamsHolder.selectionStyle = style
        return self
    }

    func mediaSelectionLimit(_ limit: Int) -> MediaPicker {
        selectionParamsHolder.selectionLimit = limit
        return self
    }

    func showFullscreenPreview(_ show: Bool) -> MediaPicker {
        selectionParamsHolder.showFullscreenPreview = show
        return self
    }

    /// When `true` (default), each grid cell uses the asset's pixel aspect
    /// ratio so portrait / landscape / video thumbnails are not cropped to
    /// squares. Set to `false` for a classic uniform square grid.
    func mediaGridUsesAssetAspectRatio(_ enabled: Bool = true) -> MediaPicker {
        selectionParamsHolder.gridUsesAssetAspectRatio = enabled
        return self
    }

    func setSelectionParameters(_ params: SelectionParamsHolder?) -> MediaPicker {
        guard let params = params else {
            return self
        }
        var mediaPicker = self
        mediaPicker.selectionParamsHolder = params
        return mediaPicker
    }

    func applyFilter(_ filterClosure: @escaping FilterClosure) -> MediaPicker {
        var mediaPicker = self
        mediaPicker.filterClosure = filterClosure
        return mediaPicker
    }

    func applyFilter(_ filterClosure: @escaping MassFilterClosure) -> MediaPicker {
        var mediaPicker = self
        mediaPicker.massFilterClosure = filterClosure
        return mediaPicker
    }

    func orientationHandler(_ orientationHandler: @escaping MediaPickerOrientationHandler) -> MediaPicker {
        var mediaPicker = self
        mediaPicker.orientationHandler = orientationHandler
        return mediaPicker
    }

    func currentFullscreenMedia(_ currentFullscreenMedia: Binding<Media?>) -> MediaPicker {
        var mediaPicker = self
        mediaPicker._currentFullscreenMediaBinding = currentFullscreenMedia
        return mediaPicker
    }

    func albums(_ albums: Binding<[Album]>) -> MediaPicker {
        var mediaPicker = self
        mediaPicker._albums = albums
        return mediaPicker
    }

    func pickerMode(_ mode: Binding<MediaPickerMode>) -> MediaPicker {
        var mediaPicker = self
        mediaPicker.pickerMode = mode
        return mediaPicker
    }
}
