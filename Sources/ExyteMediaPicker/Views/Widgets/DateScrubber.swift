//
//  DateScrubber.swift
//  ExyteMediaPicker
//
//  Right-edge scrubber inspired by the iOS Photos app. The rail shows
//  small month abbreviations spaced along the album. Dragging anywhere on
//  the rail produces an `onScrub` callback with the section under the
//  finger so the caller can scroll the grid (via `ScrollViewReader`) and
//  show a floating date pill.
//

import SwiftUI

struct DateScrubber: View {

    /// Fixed width of the rail (overlay, does not push content).
    static let width: CGFloat = 18

    let sections: [AlbumDateSection]
    /// Called continuously while the user drags. Receives the section the
    /// finger is currently over plus the y-coordinate (in the rail's local
    /// space) so the caller can position a floating date label.
    var onScrub: (AlbumDateSection, CGFloat) -> Void
    /// Called when the drag ends so the caller can hide the floating label.
    var onScrubEnd: () -> Void

    @State private var isDragging = false

    /// One entry per distinct month, used as the visible markers on the rail.
    private var monthMarkers: [(label: String, section: AlbumDateSection)] {
        var seen = Set<String>()
        var result: [(String, AlbumDateSection)] = []
        let calendar = Calendar.current
        for section in sections {
            guard let date = section.items.first?.asset.creationDate else { continue }
            let key = "\(calendar.component(.year, from: date))-\(calendar.component(.month, from: date))"
            if !seen.contains(key) {
                seen.insert(key)
                result.append((Self.monthAbbrev(for: date), section))
            }
        }
        return result
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .center) {
                if !sections.isEmpty {
                    // Subtle vertical guide line.
                    Capsule()
                        .fill(Color.secondary.opacity(isDragging ? 0.5 : 0.2))
                        .frame(width: 2)
                        .padding(.vertical, 4)

                    // Month labels distributed evenly along the rail.
                    VStack(spacing: 0) {
                        ForEach(Array(monthMarkers.enumerated()), id: \.offset) { _, item in
                            Text(item.label)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
            .frame(width: Self.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(scrubGesture(railHeight: geo.size.height))
        }
        .frame(width: Self.width)
    }

    private func scrubGesture(railHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !sections.isEmpty else { return }
                isDragging = true
                let clampedY = max(0, min(value.location.y, railHeight))
                let progress = railHeight > 0 ? clampedY / railHeight : 0
                let index = min(Int(progress * CGFloat(sections.count)), sections.count - 1)
                onScrub(sections[index], clampedY)
            }
            .onEnded { _ in
                isDragging = false
                onScrubEnd()
            }
    }

    private static func monthAbbrev(for date: Date) -> String {
        let formatter = DateFormatter()
        let isPortuguese = Locale.preferredLanguages.first?.hasPrefix("pt") ?? false
        formatter.locale = Locale(identifier: isPortuguese ? "pt_BR" : "en_US")
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: date).uppercased()
    }
}
