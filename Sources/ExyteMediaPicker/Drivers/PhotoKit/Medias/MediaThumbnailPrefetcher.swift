//
//  MediaThumbnailPrefetcher.swift
//  ExyteMediaPicker
//

#if os(iOS)
import Photos
import UIKit

enum MediaThumbnailPrefetcher {

    private static let lock = NSLock()
    private static var cachedAssets: [PHAsset] = []
    private static var cachedTargetSize: CGSize = .zero
    private static var cachedContentMode: PHImageContentMode = .aspectFill

    private static let defaultGridSpacing: CGFloat = 2
    private static let defaultHorizontalPadding: CGFloat = 2

    static func prefetchThumbnailGridPriming(
        models: [AssetMediaModel],
        columnsCount: Int,
        maxAssets: Int = 48
    ) {
        guard !models.isEmpty, columnsCount > 0 else { return }

        stopCaching()

        let bounds = UIScreen.main.bounds
        let usableWidth = bounds.width - defaultHorizontalPadding * 2
        let rawCell = (usableWidth - CGFloat(columnsCount - 1) * defaultGridSpacing) / CGFloat(columnsCount)
        let scale = UIScreen.main.scale
        let edge = max(rawCell * scale, 80)
        let targetSize = CGSize(width: edge, height: edge)
        let assets = Array(models.prefix(maxAssets).map(\.asset))

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic

        let manager = PHCachingImageManager.default() as! PHCachingImageManager
        manager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: PHImageContentMode.aspectFill,
            options: options
        )

        lock.lock()
        cachedAssets = assets
        cachedTargetSize = targetSize
        cachedContentMode = .aspectFill
        lock.unlock()
    }

    static func stopCaching() {
        lock.lock()
        let assets = cachedAssets
        let size = cachedTargetSize
        let mode = cachedContentMode
        cachedAssets = []
        cachedTargetSize = .zero
        lock.unlock()

        guard !assets.isEmpty, size.width > 0, size.height > 0 else { return }

        let manager = PHCachingImageManager.default() as! PHCachingImageManager
        manager.stopCachingImages(for: assets, targetSize: size, contentMode: mode, options: nil)
    }
}
#endif
