//
//  AlbumQuickAccessBar.swift
//  ExyteMediaPicker
//
//  Horizontal shortcuts (Recents, Favorites, …) inspired by the iOS Photos picker.
//

import SwiftUI

enum AlbumQuickAccessItem: Identifiable, Equatable {
    case recents
    case smartAlbum(SmartAlbumKind)
    case browseAlbums

    var id: String {
        switch self {
        case .recents:
            return "recents"
        case .smartAlbum(let kind):
            return "smart-\(kind.rawValue)"
        case .browseAlbums:
            return "browse-albums"
        }
    }
}

struct AlbumQuickAccessBar: View {

    @ObservedObject var viewModel: MediaPickerViewModel
    @EnvironmentObject private var selectionParamsHolder: SelectionParamsHolder
    @Environment(\.mediaPickerTheme) private var theme

    private var items: [AlbumQuickAccessItem] {
        viewModel.quickAccessItems(for: selectionParamsHolder.mediaType)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    quickAccessChip(item)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
        }
        .padding(.vertical, 8)
        .background(theme.main.albumSelectionBackground)
    }

    @ViewBuilder
    private func quickAccessChip(_ item: AlbumQuickAccessItem) -> some View {
        let selected = viewModel.isQuickAccessSelected(item, mode: viewModel.internalPickerMode)
        Button {
            viewModel.applyQuickAccess(item)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: item.systemImageName)
                    .font(.system(size: 13, weight: .semibold))
                Text(item.title)
                    .font(.system(size: 14, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? theme.selection.selectedTint : theme.main.text.opacity(0.88))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        selected
                            ? theme.selection.selectedTint.opacity(0.2)
                            : theme.main.text.opacity(0.1)
                    )
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        selected ? theme.selection.selectedTint.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private extension AlbumQuickAccessItem {
    var title: String {
        switch self {
        case .recents:
            return SmartAlbumKind.allPhotos.localizedTitle
        case .smartAlbum(let kind):
            return kind.localizedTitle
        case .browseAlbums:
            let isPortuguese = Locale.preferredLanguages.first?.hasPrefix("pt") ?? false
            return isPortuguese ? "Álbuns" : "Albums"
        }
    }

    var systemImageName: String {
        switch self {
        case .recents:
            return SmartAlbumKind.allPhotos.systemImageName
        case .smartAlbum(let kind):
            return kind.systemImageName
        case .browseAlbums:
            return "rectangle.stack"
        }
    }
}
