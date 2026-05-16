//
//  AlbumScrollDateIndicator.swift
//  ExyteMediaPicker
//
//  Passive month/year pill while the user scrolls the grid (no rail scrubbing).
//

import SwiftUI

struct AlbumScrollAnchorPosition: Equatable {
  let id: String
  let minY: CGFloat
}

struct AlbumScrollAnchorPreferenceKey: PreferenceKey {
  static var defaultValue: [AlbumScrollAnchorPosition] = []

  static func reduce(value: inout [AlbumScrollAnchorPosition], nextValue: () -> [AlbumScrollAnchorPosition]) {
    value.append(contentsOf: nextValue())
  }
}

struct AlbumScrollAnchorReporter: ViewModifier {
  let assetId: String
  let isSectionAnchor: Bool

  func body(content: Content) -> some View {
    content.background {
      if isSectionAnchor {
        GeometryReader { geometry in
          Color.clear.preference(
            key: AlbumScrollAnchorPreferenceKey.self,
            value: [
              AlbumScrollAnchorPosition(
                id: assetId,
                minY: geometry.frame(in: .named("albumScroll")).minY
              )
            ]
          )
        }
      }
    }
  }
}

struct AlbumScrollDateIndicatorOverlay: View {
  let label: String
  let isVisible: Bool

  var body: some View {
    if isVisible, !label.isEmpty {
      Text(label)
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundColor(.primary)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: true)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: Capsule())
        .overlay(
          Capsule()
            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 2)
        .padding(.trailing, 12)
        .padding(.top, 72)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .transition(.opacity)
        .allowsHitTesting(false)
    }
  }
}
