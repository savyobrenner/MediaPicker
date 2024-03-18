//
//  Created by Alex.M on 27.05.2022.
//

import SwiftUI

struct AlbumView: View {
    
    @EnvironmentObject private var selectionService: SelectionService
    @EnvironmentObject private var permissionsService: PermissionsService
    @Environment(\.mediaPickerTheme) private var theme
    
    @ObservedObject var keyboardHeightHelper = KeyboardHeightHelper.shared
    
    @StateObject var viewModel: AlbumViewModel
    @Binding var showingCamera: Bool
    @Binding var isInFullscreen: Bool
    @Binding var currentFullscreenMedia: Media?
    
    var shouldShowCamera: Bool
    var shouldShowLoadingCell: Bool
    var selectionParamsHolder: SelectionParamsHolder
    var shouldDismiss: ()->()
    
    @State private var fullscreenItem: AssetMediaModel?
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let spacing: CGFloat = 8
            let padding: CGFloat = 4
            let numberOfItemsPerRow: CGFloat = 3
            let totalPadding = padding * 2
            let totalSpacing = (numberOfItemsPerRow - 1) * spacing
            let itemWidth = (screenWidth - totalSpacing - totalPadding) / numberOfItemsPerRow
            
            ScrollView {
                VStack {
                    if let action = permissionsService.photoLibraryAction {
                        PermissionsActionView(action: .library(action))
                    }
                    if shouldShowCamera, let action = permissionsService.cameraAction {
                        PermissionsActionView(action: .camera(action))
                    }
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(width: 150, height: 150)
                            .tint(.white)
                    } else if viewModel.assetMediaModels.isEmpty, !shouldShowLoadingCell {
                        Text("There is no photos here")
                            .font(.title3)
                            .foregroundColor(theme.main.text)
                    } else {
                        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: Int(numberOfItemsPerRow)), spacing: spacing) {
                            ForEach(viewModel.assetMediaModels) { assetMediaModel in
                                cellView(assetMediaModel)
                                    .frame(width: itemWidth, height: itemWidth)
                            }
                        }
                        .padding([.horizontal], padding)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .background(theme.main.albumSelectionBackground)
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
    }
    
    func fullscreenPresentedBinding() -> Binding<Bool> {
        Binding(
            get: { fullscreenItem != nil },
            set: { value in
                if !value {
                    fullscreenItem = nil
                }
            }
        )
    }
    
    @ViewBuilder
    func cellView(_ assetMediaModel: AssetMediaModel) -> some View {
        MediaCell(viewModel: MediaViewModel(assetMediaModel: assetMediaModel))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectionService.index(of: assetMediaModel) != nil ? theme.selection.selectedTint : theme.main.albumSelectionBackground, lineWidth: 1.5)
            )
            .padding(4)
            .onTapGesture {
                onSelect(assetMediaModel: assetMediaModel)
            }
    }
    
    func onSelect(assetMediaModel: AssetMediaModel) {
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
}
