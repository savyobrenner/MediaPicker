//
//  Created by Alex.M on 08.06.2022.
//

import Foundation
import Combine
import Photos

final class PermissionsService: ObservableObject {
    @Published var photoLibraryAction: PhotoLibraryAction? = .authorize

    private var subscriptions = Set<AnyCancellable>()

    init() {
        photoLibraryChangePermissionPublisher
            .sink { [weak self] in
                self?.checkPhotoLibraryAuthorizationStatus()
            }
            .store(in: &subscriptions)

        checkPhotoLibraryAuthorizationStatus()
    }

    func askLibraryPermissionIfNeeded() {
        checkPhotoLibraryAuthorizationStatus()
    }

    /// photoLibraryChangePermissionPublisher gets called multiple times even when nothing changed in photo library, so just use this one to make sure the closure runs exactly once
    static func requestPermission(_ permissionGrantedClosure: @escaping ()->()) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized || status == .limited {
                permissionGrantedClosure()
            }
        }
    }
}

private extension PermissionsService {
    func checkPhotoLibraryAuthorizationStatus() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        handle(photoLibrary: status)
    }

    func handle(photoLibrary status: PHAuthorizationStatus) {
        var result: PhotoLibraryAction?
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                self?.handle(photoLibrary: status)
            }
        case .restricted:
            // TODO: Make sure that access can't change when status == .restricted
            result = .unavailable
        case .denied:
            result = .authorize
        case .authorized:
            // Do nothing
            break
        case .limited:
            result = .selectMore
        @unknown default:
            result = .unknown
        }

        DispatchQueue.main.async { [weak self] in
            self?.photoLibraryAction = result
        }
    }
}

extension PermissionsService {
    enum PhotoLibraryAction {
        case selectMore
        case authorize
        case unavailable
        case unknown
    }
}
