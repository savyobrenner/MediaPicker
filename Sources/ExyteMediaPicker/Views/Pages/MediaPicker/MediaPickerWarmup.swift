//
//  MediaPickerWarmup.swift
//  ExyteMediaPicker
//
//  Builds the in-memory PhotoKit index (asset list + date sections) before the picker opens,
//  then primes thumbnails for the first grid screen only.
//
//  Call `activateOnAppLaunch()` from the host app `@main` init (recommended) after library permission.
//

import Foundation
import Photos
import Combine

#if canImport(UIKit)
import UIKit
#endif

public enum MediaPickerWarmup {

    private static let lock = NSLock()
    private static var inFlight = Set<MediaSelectionType>()
    private static var didScheduleLaunchWarmup = false

    static let libraryCacheReadyPublisher = PassthroughSubject<MediaSelectionType, Never>()

    /// Call from the host app at startup. Safe to call multiple times.
    public static func activateOnAppLaunch() {
#if canImport(UIKit)
        MediaPickerLaunchRegistration.ensureRegistered()
#endif
        scheduleWarmupOnAppLaunch()
    }

    /// Builds index cache only if missing, then primes the first screen of thumbnails.
    public static func prepareLibraryCacheIfNeeded(mediaType: MediaSelectionType) {
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

    /// Forces index rebuild even if a cache entry exists (rare; prefer `prepareLibraryCacheIfNeeded`).
    public static func prepareLibraryCache(mediaType: MediaSelectionType) {
        AllPhotosLibraryCache.shared.removeEntry(for: mediaType)
        lock.lock()
        inFlight.remove(mediaType)
        lock.unlock()
        prepareLibraryCacheIfNeeded(mediaType: mediaType)
    }

    public static func installAutomaticWarmupWhenLibraryAuthorized() {
        activateOnAppLaunch()
    }

    static func isWarmingUp(mediaType: MediaSelectionType) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return inFlight.contains(mediaType)
    }

    private static func scheduleWarmupOnAppLaunch() {
        lock.lock()
        guard !didScheduleLaunchWarmup else {
            lock.unlock()
            return
        }
        didScheduleLaunchWarmup = true
        lock.unlock()

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }

        prepareLibraryCacheIfNeeded(mediaType: .photo)
    }

    private static func runWarmup(mediaType: MediaSelectionType) {
        PermissionsService.requestPermission {
            DispatchQueue.global(qos: .userInitiated).async {
                let fetchResult = MediasProvider.fetchAssetsFetchResult(mediaSelectionType: mediaType)
                let quickFp = MediasProvider.quickFingerprint(fetchResult: fetchResult)

                if let existing = AllPhotosLibraryCache.shared.entry(for: mediaType),
                   existing.quickFingerprint == quickFp {
                    DispatchQueue.main.async {
                        primeThumbnails(for: existing.models)
                        lock.lock()
                        inFlight.remove(mediaType)
                        lock.unlock()
                        libraryCacheReadyPublisher.send(mediaType)
                    }
                    return
                }

                let assets = MediasProvider.map(fetchResult: fetchResult, mediaSelectionType: mediaType)
                let sections = AlbumDateSectionBuilder.makeSections(from: assets)

                AllPhotosLibraryCache.shared.store(
                    models: assets,
                    sections: sections,
                    mediaType: mediaType,
                    quickFingerprint: quickFp
                )

                DispatchQueue.main.async {
                    primeThumbnails(for: assets)
                    lock.lock()
                    inFlight.remove(mediaType)
                    lock.unlock()
                    libraryCacheReadyPublisher.send(mediaType)
                }
            }
        }
    }

#if os(iOS)
    private static func primeThumbnails(for models: [AssetMediaModel]) {
        MediaThumbnailPrefetcher.primeFirstScreenIfNeeded(models: models)
    }
#else
    private static func primeThumbnails(for models: [AssetMediaModel]) {}
#endif
}

#if canImport(UIKit)
private enum MediaPickerLaunchRegistration {

    private static let registerOnce: Void = {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { _ in
            MediaPickerWarmup.activateOnAppLaunch()
        }
        return ()
    }()

    static func ensureRegistered() {
        _ = registerOnce
    }
}
#endif
