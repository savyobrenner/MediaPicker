//
//  DateScrubber.swift
//  ExyteMediaPicker
//
//  Minimal right-edge scrubber inspired by iOS Photos. Visually it's just
//  a thin vertical hairline; while the user drags it the line thickens
//  slightly and a floating date pill ("hover") appears next to the
//  finger, telling the caller which section is under the touch via the
//  `onScrub` callback.
//

import SwiftUI

struct DateScrubber: View {

    /// Touch target width. Visually the rail is much thinner — the rest
    /// of this width is invisible padding so the drag is easy to start.
    static let width: CGFloat = 22

    let sections: [AlbumDateSection]
    /// Called continuously while the user drags. Receives the section the
    /// finger is currently over plus the y-coordinate (in the rail's
    /// local space) so the caller can position the floating date pill.
    var onScrub: (AlbumDateSection, CGFloat) -> Void
    /// Called when the drag ends so the caller can hide the floating pill.
    var onScrubEnd: () -> Void

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Capsule()
                    .fill(Color.secondary.opacity(isDragging ? 0.7 : 0.25))
                    .frame(width: isDragging ? 3 : 2)
                    .padding(.vertical, 6)
                    .animation(.easeOut(duration: 0.15), value: isDragging)
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
}
