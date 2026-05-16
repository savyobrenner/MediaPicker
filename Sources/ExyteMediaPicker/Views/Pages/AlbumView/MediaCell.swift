//
//  Created by Alex.M on 27.05.2022.
//
//  Native-looking media tile inspired by the iOS 26 Photos app:
//  - optional natural aspect ratio from PHAsset pixel dimensions
//  - subtle badges: Live Photo (top-left), Burst (top-left), video
//    duration (bottom-right)
//  - selection indicator: numbered circle / checkmark
//

import SwiftUI
import Photos

struct MediaCell: View {

    @StateObject private var viewModel: MediaViewModel

    @Environment(\.mediaPickerTheme) private var theme
    @EnvironmentObject private var selectionService: SelectionService

    let selectionParamsHolder: SelectionParamsHolder

    init(assetMediaModel: AssetMediaModel, selectionParamsHolder: SelectionParamsHolder) {
        _viewModel = StateObject(wrappedValue: MediaViewModel(assetMediaModel: assetMediaModel))
        self.selectionParamsHolder = selectionParamsHolder
    }

    /// Shared by thumbnail clip and selection ring so corners stay aligned.
    private var cellCornerRadius: CGFloat { 10 }

    private var selectionIndex: Int? {
        selectionService.index(of: viewModel.assetMediaModel)
    }
    
    private var canSelect: Bool {
        selectionService.canSelect(assetMediaModel: viewModel.assetMediaModel)
    }
    
    /// Width ÷ height from PhotoKit (falls back to 1:1 if unknown).
    private var assetAspectRatio: CGFloat {
        let a = viewModel.assetMediaModel.asset
        let w = CGFloat(max(a.pixelWidth, 1))
        let h = CGFloat(max(a.pixelHeight, 1))
        return w / h
    }
    
    /// In aspect-ratio mode the cell IS the asset's shape, so the
    /// thumbnail fills it exactly (no letterbox).
    var body: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { geometry in
                ThumbnailView(preview: viewModel.preview, imageContentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .onAppear {
                        viewModel.onStart(size: geometry.size)
                    }
            }
            .aspectRatio(
                selectionParamsHolder.gridUsesAssetAspectRatio ? assetAspectRatio : 1,
                contentMode: .fit
            )
            
            bottomOverlay
            topLeftBadges
            selectionBadge
        }
        .background(Color(uiColor: .secondarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: cellCornerRadius, style: .continuous))
        .overlay(selectionBorder)
        .onDisappear {
            viewModel.onStop()
        }
    }
    
    // MARK: - Layers
    
    private var bottomOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if let duration = viewModel.assetMediaModel.asset.formattedDuration {
                    Text(duration)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 1, y: 0.5)
                        .padding(.trailing, 4)
                        .padding(.bottom, 4)
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    @ViewBuilder
    private var topLeftBadges: some View {
        let asset = viewModel.assetMediaModel.asset
        let isLive = asset.mediaSubtypes.contains(.photoLive)
        let isBurst = asset.representsBurst
        
        if isLive || isBurst {
            VStack {
                HStack {
                    if isLive {
                        Image(systemName: "livephoto")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 1, y: 0.5)
                            .padding(6)
                    } else if isBurst {
                        Image(systemName: "square.stack.3d.down.right.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 1, y: 0.5)
                            .padding(6)
                    }
                    Spacer()
                }
                Spacer()
            }
            .allowsHitTesting(false)
        }
    }
    
    @ViewBuilder
    private var selectionBadge: some View {
        let style = selectionParamsHolder.selectionStyle
        switch style {
        case .count, .border:
            countBadge
        case .checkmark:
            checkmarkBadge
        }
    }
    
    @ViewBuilder
    private var countBadge: some View {
        if let index = selectionIndex {
            Text("\(index + 1)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(theme.selection.selectedTint))
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                .padding(6)
                .allowsHitTesting(false)
        } else if canSelect {
            Circle()
                .stroke(.white, lineWidth: 1.5)
                .background(Circle().fill(.black.opacity(0.2)))
                .frame(width: 24, height: 24)
                .padding(6)
                .allowsHitTesting(false)
        }
    }
    
    @ViewBuilder
    private var checkmarkBadge: some View {
        if selectionIndex != nil {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(theme.selection.selectedTint)
                .background(Circle().fill(.white))
                .padding(6)
                .allowsHitTesting(false)
        } else if canSelect {
            Image(systemName: "circle")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(.white)
                .padding(6)
                .allowsHitTesting(false)
        }
    }
    
    @ViewBuilder
    private var selectionBorder: some View {
        if selectionIndex != nil {
            RoundedRectangle(cornerRadius: cellCornerRadius, style: .continuous)
                .strokeBorder(
                    theme.selection.selectedTint.opacity(0.88),
                    lineWidth: 2
                )
                .shadow(color: theme.selection.selectedTint.opacity(0.28), radius: 4, x: 0, y: 0)
        }
    }
}
