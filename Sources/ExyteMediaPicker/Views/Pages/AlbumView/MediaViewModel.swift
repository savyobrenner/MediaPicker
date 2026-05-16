//
//  Created by Alex.M on 03.06.2022.
//

#if os(iOS)
import UIKit.UIImage
#endif
import Photos

final class MediaViewModel: ObservableObject {
    let assetMediaModel: AssetMediaModel

    private var requestID: PHImageRequestID?

    init(assetMediaModel: AssetMediaModel) {
        self.assetMediaModel = assetMediaModel
    }

#if os(iOS)
    @Published var preview: UIImage? = nil
#else
    // FIXME: Create preview for image/video for other platforms
#endif

    func onStart(size: CGSize) {
        onStop()
        requestID = assetMediaModel.asset.image(size: size) { [weak self] image in
            self?.preview = image
        }
    }

    func onStop() {
        if let requestID {
            PHCachingImageManager.default().cancelImageRequest(requestID)
            self.requestID = nil
        }
#if os(iOS)
        preview = nil
#endif
    }

    deinit {
        onStop()
    }
}
