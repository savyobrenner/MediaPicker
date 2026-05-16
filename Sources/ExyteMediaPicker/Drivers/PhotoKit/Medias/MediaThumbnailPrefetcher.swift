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
        maxAssets: Int = 72
    ) {
        guard !models.isEmpty, columnsCount > 0 else { return }

        stopCaching()

        let targetSize = Self.gridThumbnailPixelSize(columnsCount: columnsCount)
        let assets = Array(models.prefix(maxAssets).map(\.asset))

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast

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

    static func gridThumbnailPixelSize(columnsCount: Int) -> CGSize {
        let bounds = UIScreen.main.bounds
        let usableWidth = bounds.width - defaultHorizontalPadding * 2
        let rawCell = (usableWidth - CGFloat(max(columnsCount - 1, 0)) * defaultGridSpacing)
            / CGFloat(max(columnsCount, 1))
        let scale = UIScreen.main.scale
        let edge = max(rawCell * scale, 300)
        return CGSize(width: edge, height: edge)
    }

    /// Primes PhotoKit cache for the first screen after the library index is ready.
    static func primeFirstScreenIfNeeded(models: [AssetMediaModel], columnsCount: Int = 3) {
        guard !models.isEmpty else { return }
        prefetchThumbnailGridPriming(models: models, columnsCount: columnsCount, maxAssets: 72)
    }

    /// Warms thumbnails around a scrub jump target so cells exist before `scrollTo` runs.
    static func prefetchWindow(
        models: [AssetMediaModel],
        around startIndex: Int,
        columnsCount: Int,
        radius: Int = 54
    ) {
        guard !models.isEmpty, columnsCount > 0, startIndex >= 0 else { return }

        let lower = max(0, startIndex - radius)
        let upper = min(models.count, startIndex + radius + 1)
        guard lower < upper else { return }

        let slice = Array(models[lower..<upper])
        prefetchThumbnailGridPriming(
            models: slice,
            columnsCount: columnsCount,
            maxAssets: slice.count
        )
    }
}
#endif
