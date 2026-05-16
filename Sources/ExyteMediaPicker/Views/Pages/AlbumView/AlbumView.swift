//
//  Created by Alex.M on 27.05.2022.
//
//  Two grid layouts:
//
//  - Masonry (Pinterest-style): when
//    `selectionParamsHolder.gridUsesAssetAspectRatio == true`. Items are
//    distributed across N columns by a greedy shortest-column heuristic
//    so each cell renders at its real aspect ratio without letterbox.
//
//  - Square grid: classic uniform layout used when the flag is false.
//
//  Both support pinch-to-zoom between 3 / 4 / 5 columns. Sections still
//  exist in the viewmodel for the right-edge date scrubber, but they no
//  longer render headers — the scroll is fully continuous and the date
//  surfaces only when the user drags the scrubber.
//

import SwiftUI

struct AlbumView: View {
    
    @EnvironmentObject private var selectionService: SelectionService
    @EnvironmentObject private var permissionsService: PermissionsService
    @Environment(\.mediaPickerTheme) private var theme
    
    @ObservedObject var keyboardHeightHelper = KeyboardHeightHelper.shared
    
    @StateObject var viewModel: AlbumViewModel
    @Binding var isInFullscreen: Bool
    @Binding var currentFullscreenMedia: Media?
    
    var shouldShowLoadingCell: Bool
    var selectionParamsHolder: SelectionParamsHolder
    var shouldDismiss: ()->()
    
    @State private var fullscreenItem: AssetMediaModel?
    @State private var columnsCount: Int = 3
    @GestureState private var pinchScale: CGFloat = 1.0

    private let columnOptions: [Int] = [3, 4, 5]
    private let cellSpacing: CGFloat = 2
    
    private var useMasonry: Bool {
        selectionParamsHolder.gridUsesAssetAspectRatio
    }

    private var shouldShowPlaceholderGrid: Bool {
        guard viewModel.assetMediaModels.isEmpty else { return false }
        switch permissionsService.photoLibraryAction {
        case .authorize, .unavailable:
            return false
        default:
            return viewModel.isAwaitingInitialLibraryLoad || viewModel.isStreamingLibraryIndex
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    if let action = permissionsService.photoLibraryAction {
                        PermissionsActionView(action: .library(action))
                            .padding(.horizontal, 16)
                    }

                    if shouldShowPlaceholderGrid {
                        placeholderGridContent
                    } else if viewModel.sections.isEmpty && !shouldShowLoadingCell && viewModel.assetMediaModels.isEmpty {
                        Text(emptyMessage)
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .padding(.top, 80)
                    } else if useMasonry {
                        masonryContent
                    } else {
                        squareGridContent
                    }
                }
                .background(theme.main.albumSelectionBackground.ignoresSafeArea())
                .gesture(magnificationGesture)
                .onTapGesture {
                    if keyboardHeightHelper.keyboardDisplayed {
                        dismissKeyboard()
                    }
                }

                if !viewModel.sections.isEmpty || !viewModel.assetMediaModels.isEmpty {
                    AlbumDateScrubberOverlay(
                        sections: viewModel.sections,
                        scrollProxy: proxy
                    )
                }
            }
        }
        .overlay {
            if let item = fullscreenItem {
                FullscreenContainer(
                    isPresented: fullscreenPresentedBinding(),
                    currentFullscreenMedia: $currentFullscreenMedia,
                    assetMediaModels: viewModel.assetMediaModels,
                    selection: item.id,
                    selectionParamsHolder: selectionParamsHolder,
                    shouldDismiss: shouldDismiss
                )
            }
        }
    }
    
    // MARK: - Masonry layout (Pinterest-style)
    
    private var masonryColumns: [[AssetMediaModel]] {
        viewModel.masonryDistribution(forColumnsCount: columnsCount)
    }

    private var masonryContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(masonryColumns.indices, id: \.self) { index in
                    LazyVStack(spacing: cellSpacing) {
                        ForEach(masonryColumns[index]) { assetMediaModel in
                            cellView(assetMediaModel)
                                .id(assetMediaModel.id)
                                .onTapGesture {
                                    onTap(assetMediaModel: assetMediaModel)
                                }
                                .onLongPressGesture(minimumDuration: 0.35) {
                                    openFullscreen(assetMediaModel: assetMediaModel)
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, cellSpacing)

            if shouldShowLoadingCell || viewModel.isStreamingLibraryIndex {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }

    private var placeholderGridContent: some View {
        let placeholders = Array(repeating: 0, count: 18)
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: cellSpacing), count: columnsCount),
            spacing: cellSpacing
        ) {
            ForEach(placeholders.indices, id: \.self) { index in
                MediaGridPlaceholderCell(aspectRatio: useMasonry ? placeholderAspect(for: index) : 1)
            }
        }
        .padding(.horizontal, cellSpacing)
        .redacted(reason: .placeholder)
    }

    private func placeholderAspect(for index: Int) -> CGFloat {
        let presets: [CGFloat] = [0.75, 1.2, 0.85, 1.0, 1.35, 0.7]
        return presets[index % presets.count]
    }
    
    // MARK: - Square grid (uniform)
    
    private var squareGridContent: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: cellSpacing), count: columnsCount),
            alignment: .leading,
            spacing: cellSpacing
        ) {
            ForEach(viewModel.assetMediaModels) { assetMediaModel in
                cellView(assetMediaModel)
                    .id(assetMediaModel.id)
                    .onTapGesture {
                        onTap(assetMediaModel: assetMediaModel)
                    }
                    .onLongPressGesture(minimumDuration: 0.35) {
                        openFullscreen(assetMediaModel: assetMediaModel)
                    }
            }
            if shouldShowLoadingCell || viewModel.isStreamingLibraryIndex {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func cellView(_ assetMediaModel: AssetMediaModel) -> some View {
        MediaCell(
            viewModel: MediaViewModel(assetMediaModel: assetMediaModel),
            selectionParamsHolder: selectionParamsHolder
        )
    }
    
    // MARK: - Pinch to zoom
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                guard let currentIndex = columnOptions.firstIndex(of: columnsCount) else {
                    columnsCount = 3
                    return
                }
                // pinch out (>1) -> bigger cells -> fewer columns
                // pinch in  (<1) -> smaller cells -> more columns
                let nextIndex: Int
                if value > 1.2 {
                    nextIndex = max(currentIndex - 1, 0)
                } else if value < 0.8 {
                    nextIndex = min(currentIndex + 1, columnOptions.count - 1)
                } else {
                    nextIndex = currentIndex
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    columnsCount = columnOptions[nextIndex]
                }
            }
    }
    
    // MARK: - Interaction
    
    private func onTap(assetMediaModel: AssetMediaModel) {
        if keyboardHeightHelper.keyboardDisplayed {
            dismissKeyboard()
        }
        
        if assetMediaModel.mediaType == .video && selectionParamsHolder.selectionLimit == 1 {
            if let currentlySelected = selectionService.selected.first {
                selectionService.onSelect(assetMediaModel: currentlySelected)
            }
        }
        selectionService.onSelect(assetMediaModel: assetMediaModel)
    }
    
    private func openFullscreen(assetMediaModel: AssetMediaModel) {
        guard selectionParamsHolder.showFullscreenPreview else { return }
        fullscreenItem = assetMediaModel
    }
    
    private func fullscreenPresentedBinding() -> Binding<Bool> {
        Binding(
            get: { fullscreenItem != nil },
            set: { value in
                if !value {
                    fullscreenItem = nil
                }
            }
        )
    }
    
    private var emptyMessage: String {
        let isPortuguese = Locale.preferredLanguages.first?.hasPrefix("pt") ?? false
        return isPortuguese ? "Sem fotos aqui" : "No photos here"
    }
}
