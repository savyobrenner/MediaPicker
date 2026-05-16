//
//  AlbumDateSectionBuilder.swift
//  ExyteMediaPicker
//

import Foundation

enum AlbumDateSectionBuilder {

  /// Groups assets by day (expects newest-first order, same as PhotoKit fetch).
  static func makeSections(from assets: [AssetMediaModel]) -> [AlbumDateSection] {
    let calendar = Calendar.current
    let now = Date()

    let isPortuguese = Locale.preferredLanguages.first?.hasPrefix("pt") ?? false
    let dayMonthFormatter = DateFormatter()
    dayMonthFormatter.locale = Locale(identifier: isPortuguese ? "pt_BR" : "en_US")
    dayMonthFormatter.setLocalizedDateFormatFromTemplate(isPortuguese ? "d 'de' MMMM" : "MMMM d")

    let monthYearFormatter = DateFormatter()
    monthYearFormatter.locale = Locale(identifier: isPortuguese ? "pt_BR" : "en_US")
    monthYearFormatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")

    var bucket: [(key: String, title: String, items: [AssetMediaModel])] = []
    var lastKey: String?

    for asset in assets {
      let date = asset.asset.creationDate ?? Date.distantPast
      let key: String
      let title: String

      if calendar.isDateInToday(date) {
        key = "today"
        title = isPortuguese ? "Hoje" : "Today"
      } else if calendar.isDateInYesterday(date) {
        key = "yesterday"
        title = isPortuguese ? "Ontem" : "Yesterday"
      } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
        key = "day-\(calendar.component(.year, from: date))-\(calendar.component(.month, from: date))-\(calendar.component(.day, from: date))"
        title = dayMonthFormatter.string(from: date).capitalized(with: isPortuguese ? Locale(identifier: "pt_BR") : Locale(identifier: "en_US"))
      } else {
        key = "month-\(calendar.component(.year, from: date))-\(calendar.component(.month, from: date))"
        title = monthYearFormatter.string(from: date).capitalized(with: isPortuguese ? Locale(identifier: "pt_BR") : Locale(identifier: "en_US"))
      }

      if lastKey == key {
        bucket[bucket.count - 1].items.append(asset)
      } else {
        bucket.append((key: key, title: title, items: [asset]))
        lastKey = key
      }
    }

    return bucket.map { AlbumDateSection(id: $0.key, title: $0.title, items: $0.items) }
  }
}
