//
//  AlbumMediasLibraryCache.swift
//  ExyteMediaPicker
//
//  In-memory cache for smart / user album grids (Favorites, etc.).
//

import Foundation

final class AlbumMediasLibraryCache {

    static let shared = AlbumMediasLibraryCache()

    struct Entry {
        let models: [AssetMediaModel]
        let sections: [AlbumDateSection]
    }

    private let lock = NSLock()
    private var storage: [String: Entry] = [:]

    private init() {}

    func cacheKey(albumId: String, mediaType: MediaSelectionType) -> String {
        "\(albumId)|\(mediaType)"
    }

    func entry(for key: String) -> Entry? {
        lock.lock()
        defer { lock.unlock() }
        guard let stored = storage[key] else { return nil }
        return Entry(
            models: stored.models,
            sections: AlbumDateSectionBuilder.makeSections(from: stored.models)
        )
    }

    func store(models: [AssetMediaModel], key: String) {
        let sections = AlbumDateSectionBuilder.makeSections(from: models)
        lock.lock()
        storage[key] = Entry(models: models, sections: sections)
        lock.unlock()
    }

    func clear() {
        lock.lock()
        storage.removeAll()
        lock.unlock()
    }
}
