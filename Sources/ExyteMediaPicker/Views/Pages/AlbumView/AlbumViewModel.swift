//
//  Created by Alex.M on 09.06.2022.
//

import Foundation
import Combine

/// Logical section grouping assets by creation date the same way the
/// iOS 26 Photos app does: "Today", "Yesterday", "September 12",
/// "September 2025"...
struct AlbumDateSection: Identifiable, Equatable {
    let id: String
    let title: String
    let items: [AssetMediaModel]
}

@MainActor
final class AlbumViewModel: ObservableObject {

    @Published var title: String? = nil
    @Published var assetMediaModels: [AssetMediaModel] = []
    @Published var sections: [AlbumDateSection] = []
    
    let mediasProvider: MediasProviderProtocol

    private var mediaCancellable: AnyCancellable?
    
    init(mediasProvider: MediasProviderProtocol) {
        self.mediasProvider = mediasProvider
        onStart()
    }
    
    func onStart() {
        mediaCancellable = mediasProvider.assetMediaModelsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] models in
                let sortedModels = models.sorted {
                    ($0.asset.creationDate ?? Date.distantPast) > ($1.asset.creationDate ?? Date.distantPast)
                }
                self?.assetMediaModels = sortedModels
                self?.sections = Self.makeSections(from: sortedModels)
            }
        
        mediasProvider.reload()
    }
    
    deinit {
        mediasProvider.cancel()
        mediaCancellable = nil
    }
    
    /// Groups assets by day, then assembles localized section headers:
    /// "Today" / "Hoje", "Yesterday" / "Ontem", "12 de setembro",
    /// "Setembro 2025".
    private static func makeSections(from assets: [AssetMediaModel]) -> [AlbumDateSection] {
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
