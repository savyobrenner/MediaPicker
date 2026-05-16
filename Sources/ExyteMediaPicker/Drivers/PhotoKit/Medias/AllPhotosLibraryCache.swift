//
//  AllPhotosLibraryCache.swift
//  ExyteMediaPicker
//

import Foundation
import Photos

final class AllPhotosLibraryCache {

    static let shared = AllPhotosLibraryCache()

    struct Entry {
        let models: [AssetMediaModel]
        let sections: [AlbumDateSection]
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

    func entry(matchingModels models: [AssetMediaModel]) -> Entry? {
        lock.lock()
        defer { lock.unlock() }
        guard let first = models.first, let last = models.last else {
            return storage.values.first { $0.models.isEmpty }
        }
        let fp = "\(models.count)|\(first.id)|\(last.id)"
        return storage.values.first { $0.quickFingerprint == fp }
    }

    func store(
        models: [AssetMediaModel],
        sections: [AlbumDateSection],
        mediaType: MediaSelectionType,
        quickFingerprint: String
    ) {
        lock.lock()
        defer { lock.unlock() }
        storage[mediaType] = Entry(models: models, sections: sections, quickFingerprint: quickFingerprint)
    }

    func removeEntry(for mediaType: MediaSelectionType) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: mediaType)
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
}
