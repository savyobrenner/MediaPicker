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
        guard let stored = storage[mediaType] else { return nil }
        return hydratedEntry(from: stored)
    }

    /// Reuse pre-built sections when the provider delivers the same model list as in cache.
    func entry(matchingModels models: [AssetMediaModel]) -> Entry? {
        lock.lock()
        defer { lock.unlock() }
        guard let first = models.first, let last = models.last else {
            if let stored = storage.values.first(where: { $0.models.isEmpty }) {
                return hydratedEntry(from: stored)
            }
            return nil
        }
        let fp = "\(models.count)|\(first.id)|\(last.id)"
        guard let stored = storage.values.first(where: { $0.quickFingerprint == fp }) else { return nil }
        return hydratedEntry(from: stored)
    }

    private func hydratedEntry(from stored: Entry) -> Entry {
        Entry(
            models: stored.models,
            sections: AlbumDateSectionBuilder.makeSections(from: stored.models),
            quickFingerprint: stored.quickFingerprint
        )
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
