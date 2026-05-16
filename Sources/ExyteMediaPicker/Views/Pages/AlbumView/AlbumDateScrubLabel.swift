//
//  AlbumDateScrubLabel.swift
//  ExyteMediaPicker
//

import Foundation

enum AlbumDateScrubLabel {

  static func title(for assetIndex: Int, in models: [AssetMediaModel]) -> String {
    guard assetIndex >= 0, assetIndex < models.count else { return "" }
    guard let date = models[assetIndex].asset.creationDate else { return "" }

    let calendar = Calendar.current
    let isPortuguese = Locale.preferredLanguages.first?.hasPrefix("pt") ?? false
    let locale = Locale(identifier: isPortuguese ? "pt_BR" : "en_US")

    if calendar.isDateInToday(date) {
      return isPortuguese ? "Hoje" : "Today"
    }
    if calendar.isDateInYesterday(date) {
      return isPortuguese ? "Ontem" : "Yesterday"
    }

    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")

    let raw = formatter.string(from: date)
    guard let first = raw.first else { return raw }
    return first.uppercased() + raw.dropFirst()
  }
}
