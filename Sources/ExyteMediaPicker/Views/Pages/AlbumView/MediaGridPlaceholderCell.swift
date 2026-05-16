//
//  MediaGridPlaceholderCell.swift
//  ExyteMediaPicker
//

import SwiftUI

/// Skeleton tile shown while the library index is still streaming in from PhotoKit.
struct MediaGridPlaceholderCell: View {

    var aspectRatio: CGFloat = 1

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(uiColor: .secondarySystemFill))
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.04), lineWidth: 0.5)
            )
    }
}
