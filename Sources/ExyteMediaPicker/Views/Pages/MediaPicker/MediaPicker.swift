//
//  Created by Alex.M on 26.05.2022.
//

import SwiftUI
import Combine

public struct MediaPicker<AlbumSelectionContent: View>: View {

    /// To provide custom buttons layout for photos grid view use actions and views provided by this closure:
    /// - standard header with photos/albums switcher
    /// - selection view you can embed in your view
    /// - is in fullscreen photo details mode
    public typealias AlbumSelectionClosure = ((ModeSwitcher, AlbumSelectionView, Bool) -> AlbumSelectionContent)

    public typealias FilterClosure = (Media) async -> Media?
    public typealias MassFilterClosure = ([Media]) async -> [Media]

    // MARK: - Parameters

    @Binding private var isPresented: Bool
    private let onChange: MediaPickerCompletionClosure

    // MARK: - View builders

    private var albumSelectionBuilder: AlbumSelectionClosure? = nil
    private var mediaTitle = "Fotos"

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
    }

    public var body: some View {
        albumSelectionContainer
            .background(theme.main.albumSelectionBackground.ignoresSafeArea())
            .environmentObject(selectionService)
            .environmentObject(permissionService)
            .onAppear {
                permissionService.askLibraryPermissionIfNeeded()

                selectionService.onChange = onChange
                selectionService.mediaSelectionLimit = selectionParamsHolder.selectionLimit

                viewModel.shouldUpdatePickerMode = { mode in
                    pickerMode?.wrappedValue = mode
                }
                viewModel.onStart()
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
                ModeSwitcher(
                    selection: modeBinding(),
                    mediaTitle: mediaTitle
                ),
                albumSelectionView,
                isInFullscreen
            )
        } else {
            VStack(spacing: 0) {
                if !isInFullscreen {
                    defaultHeaderView
                } else {
                    Color.clear.frame(height: 15)
                }
                albumSelectionView
            }
        }
    }

    var defaultHeaderView: some View {
        HStack {
            Button("Cancelar") {
                selectionService.removeAll()
                isPresented = false
            }

            Spacer()

            Picker("", selection:
                    Binding(
                        get: { viewModel.internalPickerMode == .albums ? 1 : 0 },
                        set: { value in
                            viewModel.setPickerMode(value == 0 ? .photos : .albums)
                        }
                    )
            ) {
                Text(mediaTitle)
                    .tag(0)
                    .foregroundColor(.init(uiColor: UIColor(red: 0.949, green: 0.698, blue: 0.188, alpha: 1)))
                Text("Albums")
                    .tag(1)
                    .foregroundColor(.init(uiColor: UIColor(red: 0.949, green: 0.698, blue: 0.188, alpha: 1)))
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(maxWidth: UIScreen.main.bounds.width / 2)

            Spacer()

            Button("Feito") {
                if selectionService.selected.isEmpty, let current = currentFullscreenMedia {
                    onChange([current])
                }
                isPresented = false
            }
        }
        .padding(12)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    func modeBinding() -> Binding<Int> {
        Binding(
            get: { viewModel.internalPickerMode == .albums ? 1 : 0 },
            set: { value in
                viewModel.setPickerMode(value == 0 ? .photos : .albums)
            }
        )
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
