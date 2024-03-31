//
//  Created by Alex.M on 31.05.2022.
//

import SwiftUI

struct ThumbnailView: View {

#if os(iOS)
    let preview: UIImage?
#else
    // FIXME: Create preview for image/video for other platforms
#endif
    
    var body: some View {
        if let preview = preview {
            GeometryReader { proxy in
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 150, height: 150)
                    .clipped()
            }
        } else {
            ThumbnailPlaceholder()
        }
    }
}
