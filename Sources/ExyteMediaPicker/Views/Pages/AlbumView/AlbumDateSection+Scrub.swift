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

    /// Maps finger position on the rail to a library index (newest = 0).
    static func assetIndex(
        progress: CGFloat,
        totalCount: Int,
        recentBiasExponent: CGFloat = 1.55
    ) -> Int {
        guard totalCount > 1 else { return 0 }
        let clamped = min(max(progress, 0), 1)
        let biased = pow(clamped, recentBiasExponent)
        return min(max(Int(biased * CGFloat(totalCount - 1)), 0), totalCount - 1)
    }
}
