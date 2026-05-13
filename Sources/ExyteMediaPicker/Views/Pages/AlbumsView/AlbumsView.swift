//
//  Created by Alex.M on 27.05.2022.
//
//  Native-looking Albums list inspired by the iOS 26 Photos app:
//  - "My Albums" section: 2-column grid of user-created albums with
//    square thumbnails and title/count underneath.
//  - "Media Types" section: vertical list of smart albums (Favorites,
//    Videos, Selfies, Live Photos, Portrait, ...) using the same SF
//    Symbols Apple uses in the Photos sidebar.
//

import SwiftUI
import Combine

struct AlbumsView: View {
    @EnvironmentObject private var selectionService: SelectionService
    @EnvironmentObject private var permissionsService: PermissionsService
    @Environment(\.mediaPickerTheme) private var theme
    
    @StateObject var viewModel: AlbumsViewModel
    @ObservedObject var mediaPickerViewModel: MediaPickerViewModel
    
    @Binding var currentFullscreenMedia: Media?
    
    let selectionParamsHolder: SelectionParamsHolder
    let filterClosure: MediaPicker.FilterClosure?
    let massFilterClosure: MediaPicker.MassFilterClosure?
    
    private let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            if let action = permissionsService.photoLibraryAction {
                PermissionsActionView(action: .library(action))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            
            if viewModel.isLoading && viewModel.smartAlbums.isEmpty && viewModel.userAlbums.isEmpty {
                ProgressView()
                    .controlSize(.large)
                    .padding(.top, 80)
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    if !viewModel.userAlbums.isEmpty {
                        myAlbumsSection
                    }
                    if !viewModel.smartAlbums.isEmpty {
                        mediaTypesSection
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .runOnceOnAppear {
            viewModel.onStart()
        }
        .onDisappear {
            viewModel.onStop()
        }
    }
    
    private var myAlbumsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(localized("Meus álbuns", "My Albums"))
            
            LazyVGrid(columns: gridColumns, spacing: 20) {
                ForEach(viewModel.userAlbums) { album in
                    UserAlbumGridCell(viewModel: AlbumCellViewModel(album: album))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            mediaPickerViewModel.setPickerMode(.album(album.toAlbum()))
                        }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var mediaTypesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(localized("Tipos de mídia", "Media Types"))
            
            VStack(spacing: 0) {
                ForEach(Array(viewModel.smartAlbums.enumerated()), id: \.element.id) { index, album in
                    Button {
                        mediaPickerViewModel.setPickerMode(.album(album.toAlbum()))
                    } label: {
                        SmartAlbumRowCell(viewModel: AlbumCellViewModel(album: album))
                    }
                    .buttonStyle(.plain)
                    
                    if index < viewModel.smartAlbums.count - 1 {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .padding(.horizontal, 16)
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 22, weight: .bold))
            .foregroundColor(theme.main.text)
            .padding(.horizontal, 16)
            .padding(.top, 8)
    }
    
    private func localized(_ ptBR: String, _ enUS: String) -> String {
        let isPortuguese = Locale.preferredLanguages.first?.hasPrefix("pt") ?? false
        return isPortuguese ? ptBR : enUS
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
