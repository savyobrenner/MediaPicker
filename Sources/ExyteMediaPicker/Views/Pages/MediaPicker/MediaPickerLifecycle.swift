//
//  MediaPickerLifecycle.swift
//  ExyteMediaPicker
//
//  Call when the picker UI is dismissed to drop decode caches held by PhotoKit / thumbnails.
//

import Foundation

public enum MediaPickerLifecycle {

    /// Releases image decode caches. Does **not** clear `AllPhotosLibraryCache` (index) so reopen stays fast.
    public static func releaseResourcesAfterPickerDismissed() {
#if os(iOS)
        MediaThumbnailPrefetcher.stopCaching()
#endif
    }

    /// Drops the in-memory PhotoKit index (~tens of MB on large libraries). Reopen will rebuild the index.
    public static func clearLibraryIndexCache() {
        AllPhotosLibraryCache.shared.clear()
    }
}
