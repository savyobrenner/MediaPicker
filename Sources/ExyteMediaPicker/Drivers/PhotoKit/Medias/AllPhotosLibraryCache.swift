//
//  AllPhotosLibraryCache.swift
//  ExyteMediaPicker
//
//  Keeps the mapped `PHAsset` → `AssetMediaModel` list between picker sessions so
//  reopening “All photos” does not repeat a full library scan.
//
//  Important: Do **not** register `PHPhotoLibraryChangeObserver` here only to clear this
//  cache — `photoLibraryDidChange` fires extremely often and would wipe the cache
//  before every reopen (felt like caching was broken). We optionally clear when the
//  user updates a **limited** library selection (see `BaseMediasProvider`).
//

import Foundation
import Photos

final class AllPhotosLibraryCache {

    static let shared = AllPhotosLibraryCache()

    struct Entry {
        let models: [AssetMediaModel]
        /// Cheap snapshot: count + newest + oldest asset ids for the current fetch options.
        let quickFingerprint: String
    }

    private let lock = NSLock()
    private var storage: [MediaSelectionType: Entry] = [:]

    private init() {}

    func entry(for mediaType: MediaSelectionType) -> Entry? {
        lock.lock()
        defer { lock.unlock() }
        return storage[mediaType]
    }

    func store(models: [AssetMediaModel], mediaType: MediaSelectionType, quickFingerprint: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[mediaType] = Entry(models: models, quickFingerprint: quickFingerprint)
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
}
