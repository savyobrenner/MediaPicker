//
//  AlbumDateSectionBuilder.swift
//  ExyteMediaPicker
//

import Foundation

enum AlbumDateSectionBuilder {

  /// Groups assets for the date scrubber (newest-first, same as PhotoKit).
  ///
  /// Buckets stay **coarse** so a small drag does not jump many years on large libraries.
  /// The grid itself stays continuous — these sections exist only for scrub targets.
  static func makeSections(from assets: [AssetMediaModel]) -> [AlbumDateSection] {
    let calendar = Calendar.current
    let now = Date()
    let currentYear = calendar.component(.year, from: now)
    let currentMonth = calendar.component(.month, from: now)

    let isPortuguese = Locale.preferredLanguages.first?.hasPrefix("pt") ?? false
    let locale = Locale(identifier: isPortuguese ? "pt_BR" : "en_US")

    let monthOnlyFormatter = DateFormatter()
    monthOnlyFormatter.locale = locale
    monthOnlyFormatter.setLocalizedDateFormatFromTemplate("MMMM")

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
      } else if assetYear == currentYear {
        if assetMonth == currentMonth {
          key = "month-current"
          title = monthOnlyFormatter.string(from: date).capitalized(with: locale)
        } else {
          key = "current-year-earlier"
          title = isPortuguese
            ? "Início de \(currentYear)"
            : "Earlier \(currentYear)"
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
