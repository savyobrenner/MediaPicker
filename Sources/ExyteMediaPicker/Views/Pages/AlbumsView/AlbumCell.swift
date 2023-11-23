//
//  Created by Alex.M on 30.05.2022.
//

import SwiftUI

struct AlbumCell: View {
    
    @StateObject var viewModel: AlbumCellViewModel
    
    @Environment(\.mediaPickerTheme) private var theme
    
    var body: some View {
        VStack {
            Rectangle()
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    GeometryReader { geometry in
                        ThumbnailView(preview: viewModel.preview)
                            .onAppear {
                                viewModel.fetchPreview(size: geometry.size)
                            }
                    }
                }
                .clipped()
                .cornerRadius(8)
                .foregroundColor(theme.main.albumSelectionBackground)
            
            if let title = viewModel.album.title,
               let quantity = viewModel.album.assetsQuantity {
                VStack {
                    HStack {
                        Text(title)
                            .font(.system(size: 14, weight: .bold))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(theme.main.text)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text(quantity)
                            .font(.system(size: 12, weight: .regular))
                            .italic()
                            .multilineTextAlignment(.leading)
                            .foregroundColor(theme.main.text)
                        
                        Spacer()
                    }
                }
            }
        }
        .onDisappear {
            viewModel.onStop()
        }
    }
}
