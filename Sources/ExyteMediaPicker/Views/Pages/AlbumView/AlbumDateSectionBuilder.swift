//
//  AlbumDateSectionBuilder.swift
//  ExyteMediaPicker
//

import Foundation

enum AlbumDateSectionBuilder {

  /// Scrubber buckets (newest-first): Today → Yesterday → current month → previous two
  /// calendar months → then one section per older month (`Dezembro 2025`, …).
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
      } else {
        let monthsAgo = monthsBetween(
          year: assetYear,
          month: assetMonth,
          andYear: currentYear,
          month: currentMonth
        )

        key = "month-\(assetYear)-\(assetMonth)"

        if monthsAgo <= 2, assetYear == currentYear {
          title = formatTitle(monthOnlyFormatter.string(from: date))
        } else {
          title = formatTitle(monthYearFormatter.string(from: date))
        }
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

  private static func monthsBetween(
    year: Int,
    month: Int,
    andYear endYear: Int,
    month endMonth: Int
  ) -> Int {
    (endYear - year) * 12 + (endMonth - month)
  }

  private static func formatTitle(_ raw: String) -> String {
    guard let first = raw.first else { return raw }
    return first.uppercased() + raw.dropFirst()
  }
}
