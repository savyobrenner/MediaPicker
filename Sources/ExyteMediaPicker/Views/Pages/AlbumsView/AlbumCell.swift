//
//  Created by Alex.M on 30.05.2022.
//
//  Two album cell variants used by AlbumsView to mimic the iOS 26 Photos
//  layout:
//  - SmartAlbumRowCell: list row with SF Symbol + title + count + chevron
//  - UserAlbumGridCell: tile with thumbnail + title + count
//

import SwiftUI

/// Native-looking list row for system smart albums (Favorites, Videos,
/// Selfies, etc.). Renders the SF Symbol that Apple uses in the iOS 26
/// Photos sidebar.
struct SmartAlbumRowCell: View {

    @StateObject var viewModel: AlbumCellViewModel
    @Environment(\.mediaPickerTheme) private var theme

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: viewModel.album.kind?.systemImageName ?? "photo")
                .font(.system(size: 22, weight: .regular))
                .frame(width: 28, height: 28)
                .foregroundStyle(.tint)

            Text(viewModel.album.title ?? "")
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(theme.main.text)

            Spacer()

            if let quantity = viewModel.album.assetsQuantity {
                Text(quantity)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

/// Native-looking tile for user-created albums. Shows a square thumbnail
/// with the title and count underneath, matching the iOS 26 Photos
/// "My Albums" section.
struct UserAlbumGridCell: View {

    @StateObject var viewModel: AlbumCellViewModel
    @Environment(\.mediaPickerTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                ThumbnailView(preview: viewModel.preview)
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onAppear {
                        viewModel.fetchPreview(size: geometry.size)
                    }
            }
            .aspectRatio(1, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemFill))
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.album.title ?? "")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(theme.main.text)
                    .lineLimit(1)

                if let quantity = viewModel.album.assetsQuantity {
                    Text(quantity)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
        .onDisappear {
            viewModel.onStop()
        }
    }
}
