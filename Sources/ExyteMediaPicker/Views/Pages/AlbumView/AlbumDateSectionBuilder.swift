//
//  AlbumDateSectionBuilder.swift
//  ExyteMediaPicker
//

import Foundation

enum AlbumDateSectionBuilder {

  /// Groups assets for the grid + date scrubber (newest-first, same as PhotoKit).
  ///
  /// Buckets are intentionally **coarse** so the right-edge scrubber does not jump years
  /// on a tiny drag (day-level sections made the rail hypersensitive on large libraries).
  ///
  /// - Today / Yesterday: own section
  /// - Current & previous calendar year: **month**
  /// - Older: **year**
  static func makeSections(from assets: [AssetMediaModel]) -> [AlbumDateSection] {
    let calendar = Calendar.current
    let now = Date()
    let currentYear = calendar.component(.year, from: now)

    let isPortuguese = Locale.preferredLanguages.first?.hasPrefix("pt") ?? false
    let locale = Locale(identifier: isPortuguese ? "pt_BR" : "en_US")

    let monthOnlyFormatter = DateFormatter()
    monthOnlyFormatter.locale = locale
    monthOnlyFormatter.setLocalizedDateFormatFromTemplate("MMMM")

    let monthYearFormatter = DateFormatter()
    monthYearFormatter.locale = locale
    monthYearFormatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")

    var sections: [AlbumDateSection] = []
    var lastKey: String?

    for (index, asset) in assets.enumerated() {
      let date = asset.asset.creationDate ?? Date.distantPast
      let assetYear = calendar.component(.year, from: date)
      let assetMonth = calendar.component(.month, from: date)

      let key: String
      let title: String

      if calendar.isDateInToday(date) {
        key = "today"
        title = isPortuguese ? "Hoje" : "Today"
      } else if calendar.isDateInYesterday(date) {
        key = "yesterday"
        title = isPortuguese ? "Ontem" : "Yesterday"
      } else if assetYear >= currentYear - 1 {
        key = "month-\(assetYear)-\(assetMonth)"
        if assetYear == currentYear {
          title = monthOnlyFormatter.string(from: date).capitalized(with: locale)
        } else {
          title = monthYearFormatter.string(from: date).capitalized(with: locale)
        }
      } else {
        key = "year-\(assetYear)"
        title = "\(assetYear)"
      }

      if lastKey != key {
        sections.append(
          AlbumDateSection(id: key, title: title, anchorAssetId: asset.id, startIndex: index)
        )
        lastKey = key
      }
    }

    return sections
  }
}
