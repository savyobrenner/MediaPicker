//
//  MediaPickerWarmup.swift
//  ExyteMediaPicker
//
//  Populates `AllPhotosLibraryCache` before the picker grid opens.
//
//  Important:
//  - Calling this only inside `MediaPicker.onAppear` is usually **too late** (same moment as the grid).
//  - For best UX, the **host app** should call `prepareLibraryCacheIfNeeded(mediaType:)` after the user
//    grants library access — e.g. app launch, onboarding, or home screen `.onAppear`.
//  - `installAutomaticWarmupWhenLibraryAuthorized()` runs once when the picker module loads and warms
//    `.photo` + `.photoAndVideo` after permission is already granted (helps 2nd+ picker open in-session).
//

import Foundation
import Photos
import Combine

public enum MediaPickerWarmup {

    private static let lock = NSLock()
    private static var inFlight = Set<MediaSelectionType>()
    private static var didInstallAutomaticWarmup = false

    /// Fires on the main queue when a media type finished warming the library index cache.
    static let libraryCacheReadyPublisher = PassthroughSubject<MediaSelectionType, Never>()

    /// Idempotent: no-op when cache is already populated or a warmup is in flight.
    public static func prepareLibraryCacheIfNeeded(mediaType: MediaSelectionType = .photoAndVideo) {
        lock.lock()
        if AllPhotosLibraryCache.shared.entry(for: mediaType) != nil {
            lock.unlock()
            return
        }
        if inFlight.contains(mediaType) {
            lock.unlock()
            return
        }
        inFlight.insert(mediaType)
        lock.unlock()

        runWarmup(mediaType: mediaType)
    }

    /// Same as `prepareLibraryCacheIfNeeded` but always rebuilds the index (e.g. after a manual refresh).
    public static func prepareLibraryCache(mediaType: MediaSelectionType = .photoAndVideo) {
        lock.lock()
        if inFlight.contains(mediaType) {
            lock.unlock()
            return
        }
        inFlight.insert(mediaType)
        lock.unlock()

        runWarmup(mediaType: mediaType)
    }

    /// Call once from the host app (e.g. `@main` App `init` or first scene `onAppear`) if you do not
    /// invoke `prepareLibraryCacheIfNeeded` yourself.
    public static func installAutomaticWarmupWhenLibraryAuthorized() {
        lock.lock()
        guard !didInstallAutomaticWarmup else {
            lock.unlock()
            return
        }
        didInstallAutomaticWarmup = true
        lock.unlock()

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }

        prepareLibraryCacheIfNeeded(mediaType: .photo)
        prepareLibraryCacheIfNeeded(mediaType: .photoAndVideo)
    }

    static func isWarmingUp(mediaType: MediaSelectionType) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return inFlight.contains(mediaType)
    }

    private static func runWarmup(mediaType: MediaSelectionType) {
        PermissionsService.requestPermission {
            DispatchQueue.global(qos: .utility).async {
                let fetchResult = MediasProvider.fetchAssetsFetchResult(mediaSelectionType: mediaType)
                let quickFp = MediasProvider.quickFingerprint(fetchResult: fetchResult)
                let assets = MediasProvider.map(fetchResult: fetchResult, mediaSelectionType: mediaType)
                let sections = AlbumDateSectionBuilder.makeSections(from: assets)

                AllPhotosLibraryCache.shared.store(
                    models: assets,
                    sections: sections,
                    mediaType: mediaType,
                    quickFingerprint: quickFp
                )

                DispatchQueue.main.async {
#if os(iOS)
                    MediaThumbnailPrefetcher.prefetchThumbnailGridPriming(models: assets, columnsCount: 3)
#endif
                    lock.lock()
                    inFlight.remove(mediaType)
                    lock.unlock()
                    libraryCacheReadyPublisher.send(mediaType)
                }
            }
        }
    }
}
