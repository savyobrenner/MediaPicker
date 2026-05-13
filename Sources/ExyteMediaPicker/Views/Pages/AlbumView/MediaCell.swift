//
//  Created by Alex.M on 27.05.2022.
//
//  Native-looking media tile inspired by the iOS 26 Photos app:
//  - zero corner radius / zero spacing (Photos uses a flush grid)
//  - subtle badges: Live Photo (top-left), Burst (top-left), video
//    duration (bottom-right) and an iCloud download indicator
//  - selection indicator: a numbered blue circle in the top-right corner
//    when the item is selected, or a hollow circle otherwise (only
//    visible when the user can still select more items).
//

import SwiftUI
import Photos

struct MediaCell: View {
    
    @StateObject var viewModel: MediaViewModel
    
    @Environment(\.mediaPickerTheme) private var theme
    @EnvironmentObject private var selectionService: SelectionService

    let selectionParamsHolder: SelectionParamsHolder
    
    private var selectionIndex: Int? {
        selectionService.index(of: viewModel.assetMediaModel)
    }
    
    private var canSelect: Bool {
        selectionService.canSelect(assetMediaModel: viewModel.assetMediaModel)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { geometry in
                ThumbnailView(preview: viewModel.preview)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .onAppear {
                        viewModel.onStart(size: geometry.size)
                    }
            }
            .aspectRatio(1, contentMode: .fit)
            
            bottomOverlay
            topLeftBadges
            selectionBadge
        }
        .background(Color(uiColor: .secondarySystemFill))
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
            Rectangle()
                .stroke(theme.selection.selectedTint, lineWidth: 3)
        }
    }
}
