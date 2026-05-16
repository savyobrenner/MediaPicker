//
//  MediaThumbnailPrefetcher.swift
//  ExyteMediaPicker
//
//  Primes `PHCachingImageManager` for the first grid cells so opening the picker
//  feels instant once asset identifiers are known.
//

#if os(iOS)
import Photos
import UIKit

enum MediaThumbnailPrefetcher {

    /// Typical grid width for prefetch — avoids waiting for cell layout.
    private static let defaultGridSpacing: CGFloat = 2
    private static let defaultHorizontalPadding: CGFloat = 2

    static func prefetchThumbnailGridPriming(
        models: [AssetMediaModel],
        columnsCount: Int,
        maxAssets: Int = 200
    ) {
        guard !models.isEmpty, columnsCount > 0 else { return }
        let bounds = UIScreen.main.bounds
        let usableWidth = bounds.width - defaultHorizontalPadding * 2
        let rawCell = (usableWidth - CGFloat(columnsCount - 1) * defaultGridSpacing) / CGFloat(columnsCount)
        let scale = UIScreen.main.scale
        let edge = max(rawCell * scale, 80)

        let targetSize = CGSize(width: edge, height: edge)
        let assets = models.prefix(maxAssets).map(\.asset)

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
    }
}
#endif
