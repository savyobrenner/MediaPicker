//
//  SelectionParamsHolder.swift
//  
//
//  Created by Alisa Mylnikova on 05.05.2023.
//

import SwiftUI

final public class SelectionParamsHolder: ObservableObject {

    @Published public var mediaType: MediaSelectionType = .photoAndVideo
    @Published public var selectionStyle: MediaSelectionStyle = .checkmark
    @Published public var selectionLimit: Int? // if nil - unlimited
    @Published public var showFullscreenPreview: Bool = true // if false, tap on image immediately selects this image and closes the picker
    /// When true, grid cells use each asset's pixel aspect ratio (PHAsset
    /// dimensions) so thumbnails are not forced to squares. When false,
    /// cells are square like the classic Photos library grid.
    @Published public var gridUsesAssetAspectRatio: Bool = true

    public init(mediaType: MediaSelectionType = .photoAndVideo, selectionStyle: MediaSelectionStyle = .checkmark, selectionLimit: Int? = nil, showFullscreenPreview: Bool = true, gridUsesAssetAspectRatio: Bool = true) {
        self.mediaType = mediaType
        self.selectionStyle = selectionStyle
        self.selectionLimit = selectionLimit
        self.showFullscreenPreview = showFullscreenPreview
        self.gridUsesAssetAspectRatio = gridUsesAssetAspectRatio
    }
}

public enum MediaSelectionStyle {
    case checkmark
    case count
    case border
}

public enum MediaSelectionType {
    case photoAndVideo
    case photo
    case video

    var allowsPhoto: Bool {
        [.photoAndVideo, .photo].contains(self)
    }

    var allowsVideo: Bool {
        [.photoAndVideo, .video].contains(self)
    }
}
