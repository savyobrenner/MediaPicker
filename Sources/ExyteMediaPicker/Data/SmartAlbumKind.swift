//
//  SmartAlbumKind.swift
//  ExyteMediaPicker
//
//  Mirrors the native iOS Photos "Media Types" / "My Albums" classification
//  so the picker UI can render the same icons, order and section that
//  Apple's Photos app uses in iOS 26.
//

import Foundation
import Photos

public enum SmartAlbumKind: String, CaseIterable, Equatable {
    case allPhotos
    case favorites
    case videos
    case selfies
    case livePhotos
    case portrait
    case longExposure
    case panoramas
    case timelapse
    case slomo
    case bursts
    case screenshots
    case animated
    case hidden

    /// PHAssetCollectionSubtype used by PhotoKit to fetch this smart album.
    var subtype: PHAssetCollectionSubtype {
        switch self {
        case .allPhotos:    return .smartAlbumUserLibrary
        case .favorites:    return .smartAlbumFavorites
        case .videos:       return .smartAlbumVideos
        case .selfies:      return .smartAlbumSelfPortraits
        case .livePhotos:   return .smartAlbumLivePhotos
        case .portrait:     return .smartAlbumDepthEffect
        case .longExposure: return .smartAlbumLongExposures
        case .panoramas:    return .smartAlbumPanoramas
        case .timelapse:    return .smartAlbumTimelapses
        case .slomo:        return .smartAlbumSlomoVideos
        case .bursts:       return .smartAlbumBursts
        case .screenshots:  return .smartAlbumScreenshots
        case .animated:     return .smartAlbumAnimated
        case .hidden:       return .smartAlbumAllHidden
        }
    }

    /// SF Symbol used by Photos iOS 26 for this album type.
    public var systemImageName: String {
        switch self {
        case .allPhotos:    return "photo.on.rectangle"
        case .favorites:    return "heart"
        case .videos:       return "video"
        case .selfies:      return "person.crop.square"
        case .livePhotos:   return "livephoto"
        case .portrait:     return "f.cursive.circle"
        case .longExposure: return "circle.dashed"
        case .panoramas:    return "pano"
        case .timelapse:    return "timelapse"
        case .slomo:        return "slowmo"
        case .bursts:       return "square.stack.3d.down.right"
        case .screenshots:  return "camera.viewfinder"
        case .animated:     return "rectangle.stack.badge.play"
        case .hidden:       return "eye.slash"
        }
    }

    /// User-facing localized title (in PT-BR / EN-US fallback).
    public var localizedTitle: String {
        switch self {
        case .allPhotos:    return localized("Recentes", "Recents")
        case .favorites:    return localized("Favoritos", "Favorites")
        case .videos:       return localized("Vídeos", "Videos")
        case .selfies:      return localized("Selfies", "Selfies")
        case .livePhotos:   return localized("Live Photos", "Live Photos")
        case .portrait:     return localized("Retrato", "Portrait")
        case .longExposure: return localized("Longa exposição", "Long Exposure")
        case .panoramas:    return localized("Panoramas", "Panoramas")
        case .timelapse:    return localized("Time-lapse", "Time-lapse")
        case .slomo:        return localized("Câmera lenta", "Slo-mo")
        case .bursts:       return localized("Rajadas", "Bursts")
        case .screenshots:  return localized("Capturas de Tela", "Screenshots")
        case .animated:     return localized("Animadas", "Animated")
        case .hidden:       return localized("Ocultas", "Hidden")
        }
    }

    /// Whether the kind should appear given a media selection filter.
    func isAvailable(for selectionType: MediaSelectionType) -> Bool {
        switch selectionType {
        case .photoAndVideo:
            return true
        case .photo:
            // Hide video-only smart albums when picker filters to photos.
            return ![.videos, .slomo, .timelapse].contains(self)
        case .video:
            // Hide photo-only smart albums when picker filters to videos.
            return ![.selfies, .livePhotos, .portrait, .longExposure,
                     .panoramas, .bursts, .screenshots, .animated].contains(self)
        }
    }

    /// Display order in the Photos app sidebar / picker.
    var sortOrder: Int {
        SmartAlbumKind.allCases.firstIndex(of: self) ?? Int.max
    }

    private func localized(_ ptBR: String, _ enUS: String) -> String {
        let isPortuguese = Locale.preferredLanguages.first?.hasPrefix("pt") ?? false
        return isPortuguese ? ptBR : enUS
    }
}
