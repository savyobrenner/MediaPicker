//
//  AlbumDateSection+Scrub.swift
//  ExyteMediaPicker
//

import Foundation

extension Array where Element == AlbumDateSection {

    /// Section whose `startIndex` is the greatest value still `<=` `assetIndex`.
    func section(containingAssetIndex assetIndex: Int) -> AlbumDateSection? {
        guard !isEmpty else { return nil }
        var lo = 0
        var hi = count - 1
        var best = 0
        while lo <= hi {
            let mid = (lo + hi) / 2
            if self[mid].startIndex <= assetIndex {
                best = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        return self[best]
    }
}

enum AlbumDateScrubMapping {

    /// Maps rail progress (0 = top/newest … 1 = bottom/oldest) to a library index.
    ///
    /// Uses the **time span** of the library, not photo count — 10k shots in 2025 no longer
    /// occupy the same rail slice as a handful from 2018.
    static func assetIndex(
        progress: CGFloat,
        models: [AssetMediaModel],
        recentBiasExponent: CGFloat = 3.4
    ) -> Int {
        guard models.count > 1 else { return 0 }

        let clamped = min(max(progress, 0), 1)
        let biased = pow(clamped, recentBiasExponent)

        let newest = models.first?.asset.creationDate ?? Date()
        let oldest = models.last?.asset.creationDate ?? newest
        let newestTI = newest.timeIntervalSince1970
        let oldestTI = oldest.timeIntervalSince1970

        guard newestTI > oldestTI else { return 0 }

        let targetTI = newestTI - Double(biased) * (newestTI - oldestTI)
        return index(forCreationTime: targetTI, in: models)
    }

    /// Newest-first array: index of the first photo at or before `target` in time.
    private static func index(forCreationTime target: TimeInterval, in models: [AssetMediaModel]) -> Int {
        var lo = 0
        var hi = models.count - 1
        var answer = models.count - 1

        while lo <= hi {
            let mid = (lo + hi) / 2
            let photoTime = models[mid].asset.creationDate?.timeIntervalSince1970 ?? 0
            if photoTime >= target {
                answer = mid
                hi = mid - 1
            } else {
                lo = mid + 1
            }
        }

        return answer
    }
}
