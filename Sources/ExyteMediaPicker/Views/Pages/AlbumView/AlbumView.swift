//
//  Created by Alex.M on 27.05.2022.
//
//  Continuous Pinterest-style grid. Month section anchors drive the passive date pill
//  while scrolling (no interactive scrub rail for now).
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
    @State private var scrollDateLabel: String = ""
    @State private var showScrollDateIndicator = false
    @State private var hideScrollDateTask: Task<Void, Never>?

    private let columnOptions: [Int] = [3, 4, 5]
    private let cellSpacing: CGFloat = 2
    
    private var useMasonry: Bool {
        selectionParamsHolder.gridUsesAssetAspectRatio
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: cellSpacing), count: columnsCount)
    }

    private var sectionAnchorIds: Set<String> {
        Set(viewModel.sections.map(\.anchorAssetId))
    }

    private var shouldShowInitialLoadingIndicator: Bool {
        guard viewModel.assetMediaModels.isEmpty else { return false }
        guard viewModel.isAwaitingInitialLibraryLoad else { return false }
        switch permissionsService.photoLibraryAction {
        case .authorize, .unavailable:
            return false
        default:
            return true
        }
    }

    var body: some View {
        ScrollView {
            if let action = permissionsService.photoLibraryAction {
                PermissionsActionView(action: .library(action))
                    .padding(.horizontal, 16)
            }

            if shouldShowInitialLoadingIndicator {
                ProgressView()
                    .tint(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
            } else if viewModel.sections.isEmpty && !shouldShowLoadingCell && viewModel.assetMediaModels.isEmpty {
                Text(emptyMessage)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding(.top, 80)
            } else if useMasonry {
                continuousMasonryContent
            } else {
                continuousSquareGridContent
            }
        }
        .coordinateSpace(name: "albumScroll")
        .background(theme.main.albumSelectionBackground.ignoresSafeArea())
        .simultaneousGesture(magnificationGesture)
        .onTapGesture {
            if keyboardHeightHelper.keyboardDisplayed {
                dismissKeyboard()
            }
        }
        .onPreferenceChange(AlbumScrollAnchorPreferenceKey.self) { positions in
            updateScrollDateIndicator(from: positions)
        }
        .overlay(alignment: .topTrailing) {
            AlbumScrollDateIndicatorOverlay(
                label: scrollDateLabel,
                isVisible: showScrollDateIndicator
            )
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
        .onChange(of: columnsCount) { newCount in
            viewModel.rebuildMasonryColumns(count: newCount)
        }
    }

    // MARK: - Continuous layouts

    private var continuousMasonryContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(viewModel.masonryColumns.indices, id: \.self) { columnIndex in
                    LazyVStack(spacing: cellSpacing) {
                        ForEach(viewModel.masonryColumns[columnIndex]) { assetMediaModel in
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

            if shouldShowLoadingCell {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }

    private var continuousSquareGridContent: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: cellSpacing) {
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
            }
            .padding(.horizontal, cellSpacing)

            if shouldShowLoadingCell {
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
            assetMediaModel: assetMediaModel,
            selectionParamsHolder: selectionParamsHolder
        )
        .modifier(
            AlbumScrollAnchorReporter(
                assetId: assetMediaModel.id,
                isSectionAnchor: sectionAnchorIds.contains(assetMediaModel.id)
            )
        )
    }

    private func updateScrollDateIndicator(from positions: [AlbumScrollAnchorPosition]) {
        guard !positions.isEmpty else { return }

        let bandTop: CGFloat = -120
        let bandBottom: CGFloat = 280

        guard let topAnchor = positions
            .filter({ $0.minY >= bandTop && $0.minY < bandBottom })
            .min(by: { $0.minY < $1.minY }),
            let index = viewModel.assetMediaModels.firstIndex(where: { $0.id == topAnchor.id })
        else { return }

        let label = AlbumDateScrubLabel.title(for: index, in: viewModel.assetMediaModels)
        guard !label.isEmpty else { return }
        bumpScrollDateIndicatorVisibility(label: label)
    }

    private func bumpScrollDateIndicatorVisibility(label: String) {
        scrollDateLabel = label
        withAnimation(.easeOut(duration: 0.12)) {
            showScrollDateIndicator = true
        }

        hideScrollDateTask?.cancel()
        hideScrollDateTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 750_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                showScrollDateIndicator = false
            }
        }
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
