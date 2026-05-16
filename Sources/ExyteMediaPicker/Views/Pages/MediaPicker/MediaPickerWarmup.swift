//
//  MediaPickerWarmup.swift
//  ExyteMediaPicker
//
//  Optional host-app hook to populate caches before presenting the picker sheet.
//

import Foundation
import Photos

public enum MediaPickerWarmup {

    /// Maps the whole library into memory cache and primes thumbnail decoding for the first grid rows.
    /// Runs only when Photo Library access is already granted or the user accepts the system prompt.
    ///
    /// - Typical call site: after onboarding / settings, or `.onAppear` of the screen that opens the picker.
    public static func prepareLibraryCache(mediaType: MediaSelectionType = .photoAndVideo) {
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
                }
            }
        }
    }
}
