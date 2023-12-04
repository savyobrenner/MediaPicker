//
//  Created by Alex.M on 27.05.2022.
//

import SwiftUI
import Combine

struct AlbumsView: View {
    @EnvironmentObject private var selectionService: SelectionService
    @EnvironmentObject private var permissionsService: PermissionsService
    @Environment(\.mediaPickerTheme) private var theme
    
    @StateObject var viewModel: AlbumsViewModel
    @ObservedObject var mediaPickerViewModel: MediaPickerViewModel
    
    @Binding var showingCamera: Bool
    @Binding var currentFullscreenMedia: Media?
    
    let selectionParamsHolder: SelectionParamsHolder
    let filterClosure: MediaPicker.FilterClosure?
    let massFilterClosure: MediaPicker.MassFilterClosure?
    
    @State private var showingLoadingCell = false
    
    private var columns: [GridItem] {
        Array(repeating: .init(.flexible(), spacing: 8), count: 2)
    }
    
    private var gridPadding: CGFloat {
        8
    }
    
    var body: some View {
        ScrollView {
            VStack {
                if let action = permissionsService.photoLibraryAction {
                    PermissionsActionView(action: .library(action))
                }
                if viewModel.isLoading {
                    ProgressView()
                        .frame(width: 150, height: 150)
                        .tint(.white)
                } else if viewModel.albums.isEmpty {
                    Text("There is no albums here")
                        .font(.title3)
                        .foregroundColor(theme.main.text)
                } else {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(viewModel.albums) { album in
                            AlbumCell(
                                viewModel: AlbumCellViewModel(album: album)
                            )
                            .padding(.all, gridPadding)
                            .onTapGesture {
                                mediaPickerViewModel.setPickerMode(.album(album.toAlbum()))
                            }
                        }
                        if showingLoadingCell {
                            ProgressView()
                                .frame(width: 150, height: 150)
                                .tint(.white)
                        }
                    }
                    .padding(.horizontal, gridPadding)
                }
                Spacer()
            }
            .padding(.top, gridPadding)
        }
        .runOnceOnAppear {
            viewModel.onStart()
        }
        .onDisappear {
            viewModel.onStop()
        }
        .background(theme.main.albumSelectionBackground)
    }
}

private struct RunOnceViewModifier: ViewModifier {
    
    @State
    private var hasRun = false
    
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !hasRun else { return }
                action()
                hasRun = true
            }
    }
}

extension View {
    func runOnceOnAppear(action: @escaping () -> Void) -> some View {
        modifier(RunOnceViewModifier(action: action))
    }
}

