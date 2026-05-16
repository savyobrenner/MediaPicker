//
//  AllPhotosLibraryCache.swift
//  ExyteMediaPicker
//
//  Keeps the mapped `PHAsset` → `AssetMediaModel` list between picker sessions so
//  reopening “All photos” does not repeat a full library scan.
//

import Foundation
import Photos

final class AllPhotosLibraryCache {

    static let shared = AllPhotosLibraryCache()

    private let lock = NSLock()
    private var storage: [MediaSelectionType: [AssetMediaModel]] = [:]
    private lazy var invalidatorRegistration: PhotoLibraryAssetsCacheInvalidator = {
        PhotoLibraryAssetsCacheInvalidator { [weak self] in
            self?.clear()
        }
    }()

    private init() {}

    func models(for mediaType: MediaSelectionType) -> [AssetMediaModel]? {
        lock.lock()
        defer { lock.unlock() }
        _ = invalidatorRegistration
        return storage[mediaType]
    }

    func store(_ models: [AssetMediaModel], mediaType: MediaSelectionType) {
        lock.lock()
        defer { lock.unlock() }
        storage[mediaType] = models
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
}

/// Debounced invalidation — `photoLibraryDidChange` can fire very frequently.
private final class PhotoLibraryAssetsCacheInvalidator: NSObject, PHPhotoLibraryChangeObserver {

    private let onInvalidate: () -> Void
    private var pendingWorkItem: DispatchWorkItem?

    init(onInvalidate: @escaping () -> Void) {
        self.onInvalidate = onInvalidate
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        pendingWorkItem?.cancel()
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        pendingWorkItem?.cancel()
        let item = DispatchWorkItem { [onInvalidate] in
            onInvalidate()
        }
        pendingWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }
}
