//
//  MediaGridPlaceholderCell.swift
//  ExyteMediaPicker
//

import SwiftUI

/// Uniform square skeleton tile while the library index streams in.
struct MediaGridPlaceholderCell: View {

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(uiColor: .tertiarySystemFill))
            .aspectRatio(1, contentMode: .fit)
            .shimmering()
    }
}
