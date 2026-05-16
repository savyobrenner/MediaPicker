//
//  AlbumAssetDate.swift
//  ExyteMediaPicker
//

import Foundation
import Photos

enum AlbumAssetDate {

  static func captureDate(for asset: PHAsset) -> Date? {
    if let created = asset.creationDate, isPlausible(created) {
      return created
    }
    if let modified = asset.modificationDate, isPlausible(modified) {
      return modified
    }
    return nil
  }

  static func isPlausible(_ date: Date) -> Bool {
    let year = Calendar.current.component(.year, from: date)
    let currentYear = Calendar.current.component(.year, from: Date())
    return year >= 2000 && year <= currentYear + 1
  }
}
