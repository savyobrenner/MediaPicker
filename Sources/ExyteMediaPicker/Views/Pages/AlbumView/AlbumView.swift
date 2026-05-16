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

    // Scrubber state
    @State private var scrubLabel: String = ""
    @State private var scrubLocationY: CGFloat = 0
    @State private var isScrubbing: Bool = false
    
    private let columnOptions: [Int] = [3, 4, 5]
    private let cellSpacing: CGFloat = 2
    
    private var useMasonry: Bool {
        selectionParamsHolder.gridUsesAssetAspectRatio
    }

    /// Central spinner while PhotoKit loads; hidden when the user must fix permission (.authorize / .unavailable), since `reload` never runs.
    private var shouldShowInitialLoadingIndicator: Bool {
        guard viewModel.isAwaitingInitialLibraryLoad else { return false }
        switch permissionsService.photoLibraryAction {
        case .authorize, .unavailable:
            return false
        case .none, .selectMore, .unknown:
            return true
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

                    if shouldShowInitialLoadingIndicator {
                        ProgressView()
                            .tint(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                    } else if viewModel.sections.isEmpty && !shouldShowLoadingCell {
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

                if !viewModel.sections.isEmpty {
                    DateScrubber(
                        sections: viewModel.sections,
                        onScrub: { section, localY in
                            handleScrub(section: section, localY: localY, proxy: proxy)
                        },
                        onScrubEnd: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isScrubbing = false
                            }
                        }
                    )
                }

                if isScrubbing {
                    Text(scrubLabel)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.thinMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 2)
                        .padding(.trailing, DateScrubber.width + 8)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .offset(y: max(scrubLocationY - 18, 0))
                        .transition(.opacity)
                        .allowsHitTesting(false)
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
    
    private var masonryContent: some View {
        // Distribute all assets across N columns in one continuous pass so
        // the scroll is uninterrupted. The viewmodel keeps `sections` only
        // for the scrubber: scrolling targets the section's first asset id.
        let distributed = distributeIntoColumns(viewModel.assetMediaModels, count: columnsCount)
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(distributed.indices, id: \.self) { index in
                    LazyVStack(spacing: cellSpacing) {
                        ForEach(distributed[index]) { assetMediaModel in
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
    
    // MARK: - Scrubber

    private func handleScrub(section: AlbumDateSection, localY: CGFloat, proxy: ScrollViewProxy) {
        scrubLabel = section.title
        scrubLocationY = localY
        if !isScrubbing {
            withAnimation(.easeIn(duration: 0.15)) {
                isScrubbing = true
            }
        }
        guard let targetId = section.items.first?.id else { return }
        // Don't animate while dragging — direct jumps feel faster and
        // avoid SwiftUI's lazy stacks flickering as we sweep through.
        proxy.scrollTo(targetId, anchor: .top)
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
