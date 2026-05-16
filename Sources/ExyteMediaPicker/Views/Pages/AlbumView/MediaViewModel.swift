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
    private var loadGeneration: UInt = 0

    init(assetMediaModel: AssetMediaModel) {
        self.assetMediaModel = assetMediaModel
    }

#if os(iOS)
    @Published var preview: UIImage? = nil
#else
    // FIXME: Create preview for image/video for other platforms
#endif

    func onStart(size: CGSize) {
        loadGeneration &+= 1
        let generation = loadGeneration
        cancelRequestOnly()

        requestID = assetMediaModel.asset.image(size: size) { [weak self] image in
            guard let self, generation == self.loadGeneration else { return }
            self.preview = image
        }
    }

    func onStop() {
        cancelRequestOnly()
    }

    private func cancelRequestOnly() {
        if let requestID {
            PHCachingImageManager.default().cancelImageRequest(requestID)
            self.requestID = nil
        }
    }

    deinit {
        cancelRequestOnly()
    }
}
