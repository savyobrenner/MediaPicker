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
//  Both support pinch-to-zoom between 3 / 4 / 5 columns and group assets
//  by creation date with localized section headers.
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
    
    var body: some View {
        ScrollView {
            if let action = permissionsService.photoLibraryAction {
                PermissionsActionView(action: .library(action))
                    .padding(.horizontal, 16)
            }
            
            if viewModel.sections.isEmpty && !shouldShowLoadingCell {
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
    
    private var masonryContent: some View {
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
            ForEach(viewModel.sections) { section in
                Section {
                    masonrySection(section)
                        .padding(.bottom, cellSpacing * 2)
                } header: {
                    sectionHeader(section.title)
                }
            }
            if shouldShowLoadingCell {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }
    
    private func masonrySection(_ section: AlbumDateSection) -> some View {
        let distributed = distributeIntoColumns(section.items, count: columnsCount)
        return HStack(alignment: .top, spacing: cellSpacing) {
            ForEach(distributed.indices, id: \.self) { index in
                LazyVStack(spacing: cellSpacing) {
                    ForEach(distributed[index]) { assetMediaModel in
                        cellView(assetMediaModel)
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
    }
    
    /// Greedy shortest-column distribution: each item is appended to the
    /// column with the smallest running height. Heights are accumulated
    /// using a unit-width assumption (height = 1 / aspectRatio).
    private func distributeIntoColumns(_ items: [AssetMediaModel], count: Int) -> [[AssetMediaModel]] {
        guard count > 0 else { return [items] }
        var columns: [[AssetMediaModel]] = Array(repeating: [], count: count)
        var heights: [Double] = Array(repeating: 0, count: count)
        
        for item in items {
            let aspect = aspectRatio(for: item)
            let h = aspect > 0 ? 1.0 / Double(aspect) : 1.0
            // Shortest column wins (ties go to the left).
            var minIndex = 0
            for i in 1..<count where heights[i] + 0.0001 < heights[minIndex] {
                minIndex = i
            }
            columns[minIndex].append(item)
            heights[minIndex] += h
        }
        return columns
    }
    
    private func aspectRatio(for item: AssetMediaModel) -> CGFloat {
        let a = item.asset
        let w = CGFloat(max(a.pixelWidth, 1))
        let h = CGFloat(max(a.pixelHeight, 1))
        return w / h
    }
    
    // MARK: - Square grid (uniform)
    
    private var squareGridContent: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: cellSpacing), count: columnsCount),
            alignment: .leading,
            spacing: cellSpacing,
            pinnedViews: [.sectionHeaders]
        ) {
            ForEach(viewModel.sections) { section in
                Section {
                    ForEach(section.items) { assetMediaModel in
                        cellView(assetMediaModel)
                            .onTapGesture {
                                onTap(assetMediaModel: assetMediaModel)
                            }
                            .onLongPressGesture(minimumDuration: 0.35) {
                                openFullscreen(assetMediaModel: assetMediaModel)
                            }
                    }
                } header: {
                    sectionHeader(section.title)
                }
            }
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
            viewModel: MediaViewModel(assetMediaModel: assetMediaModel),
            selectionParamsHolder: selectionParamsHolder
        )
    }
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(theme.main.text)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.main.albumSelectionBackground.opacity(0.95))
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
