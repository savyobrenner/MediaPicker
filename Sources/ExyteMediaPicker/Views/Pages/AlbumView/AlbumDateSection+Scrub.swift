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
