import AVFoundation
import Photos
import PhotosUI
import UniformTypeIdentifiers
import UIKit

enum LocalMediaSelectionError: LocalizedError {
    case cancelled
    case permissionDenied
    case parsingFailed
    case unsupported
    case persistenceFailed

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Selection cancelled."
        case .permissionDenied: return "Photo library or camera access is required to choose local media."
        case .parsingFailed: return "That local file could not be read. Please try another one."
        case .unsupported: return "This media type is not supported."
        case .persistenceFailed: return "The selected media could not be saved."
        }
    }
}

/// Facade kept separate from permission-only services so screens can depend on one picker API.
@MainActor
enum LocalMediaSelectionService {
    static func pickImages(from presenter: UIViewController, maxCount: Int = 6, completion: @escaping (Result<[String], Error>) -> Void) {
        LocalMediaPicker.shared.pickImages(from: presenter, maxCount: maxCount, completion: completion)
    }

    static func pickVideo(from presenter: UIViewController, completion: @escaping (Result<[String], Error>) -> Void) {
        LocalMediaPicker.shared.pickVideo(from: presenter, completion: completion)
    }

    static func capturePhoto(from presenter: UIViewController, completion: @escaping (Result<[String], Error>) -> Void) {
        LocalMediaPicker.shared.capturePhoto(from: presenter, completion: completion)
    }
}

/// Persists only user-selected bytes in Application Support and returns a local path token.
enum LocalMediaTokenStore {
    static func persist(data: Data, fileExtension: String) throws -> String {
        let fm = FileManager.default
        let root = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("KinvaMedia", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            throw LocalMediaSelectionError.persistenceFailed
        }
    }
}

@MainActor
final class LocalMediaPicker: NSObject, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    static let shared = LocalMediaPicker()

    private var completion: ((Result<[String], Error>) -> Void)?
    private var expectsVideo = false

    func pickImages(from presenter: UIViewController, maxCount: Int = 6, completion: @escaping (Result<[String], Error>) -> Void) {
        pick(from: presenter, filter: .images, maxCount: maxCount, expectsVideo: false, completion: completion)
    }

    func pickVideo(from presenter: UIViewController, completion: @escaping (Result<[String], Error>) -> Void) {
        pick(from: presenter, filter: .videos, maxCount: 1, expectsVideo: true, completion: completion)
    }

    func recordVideo(from presenter: UIViewController, completion: @escaping (Result<[String], Error>) -> Void) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            completion(.failure(LocalMediaSelectionError.unsupported))
            return
        }
        self.completion = completion
        expectsVideo = true
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.movie.identifier]
        picker.cameraCaptureMode = .video
        picker.videoQuality = .typeHigh
        presenter.present(picker, animated: true)
    }

    func capturePhoto(from presenter: UIViewController, completion: @escaping (Result<[String], Error>) -> Void) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            completion(.failure(LocalMediaSelectionError.unsupported))
            return
        }
        LocalMediaPermissionService.requestCamera { [weak self, weak presenter] allowed in
            guard let self, let presenter else { return }
            guard allowed else {
                completion(.failure(LocalMediaSelectionError.permissionDenied))
                return
            }
            self.completion = completion
            self.expectsVideo = false
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .camera
            picker.mediaTypes = [UTType.image.identifier]
            picker.cameraCaptureMode = .photo
            presenter.present(picker, animated: true)
        }
    }

    private func pick(from presenter: UIViewController, filter: PHPickerFilter, maxCount: Int, expectsVideo: Bool, completion: @escaping (Result<[String], Error>) -> Void) {
        let presentPicker = { [weak self, weak presenter] in
            guard let self, let presenter else { return }
            self.completion = completion
            self.expectsVideo = expectsVideo
            var configuration = PHPickerConfiguration(photoLibrary: .shared())
            configuration.filter = filter
            configuration.selectionLimit = max(1, maxCount)
            configuration.preferredAssetRepresentationMode = .current
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            presenter.present(picker, animated: true)
        }
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited: presentPicker()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { state in
                DispatchQueue.main.async {
                    guard state == .authorized || state == .limited else { completion(.failure(LocalMediaSelectionError.permissionDenied)); return }
                    presentPicker()
                }
            }
        default: completion(.failure(LocalMediaSelectionError.permissionDenied))
        }
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else {
            finish(.failure(LocalMediaSelectionError.cancelled)); return
        }
        let expectsVideo = self.expectsVideo
        let group = DispatchGroup()
        var tokens = [String]()
        var firstError: Error?
        let lock = NSLock()
        for result in results {
            group.enter()
            let provider = result.itemProvider
            if expectsVideo {
                guard provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
                    lock.lock(); firstError = LocalMediaSelectionError.unsupported; lock.unlock(); group.leave(); continue
                }
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    defer { group.leave() }
                    guard let url, error == nil else { lock.lock(); firstError = LocalMediaSelectionError.parsingFailed; lock.unlock(); return }
                    do {
                        let data = try Data(contentsOf: url)
                        let token = try LocalMediaTokenStore.persist(data: data, fileExtension: url.pathExtension.isEmpty ? "mov" : url.pathExtension)
                        lock.lock(); tokens.append(token); lock.unlock()
                    } catch { lock.lock(); firstError = error; lock.unlock() }
                }
            } else {
                guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
                    lock.lock(); firstError = LocalMediaSelectionError.unsupported; lock.unlock(); group.leave(); continue
                }
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                    defer { group.leave() }
                    guard let data, error == nil, UIImage(data: data) != nil else { lock.lock(); firstError = LocalMediaSelectionError.parsingFailed; lock.unlock(); return }
                    do {
                        let token = try LocalMediaTokenStore.persist(data: data, fileExtension: "jpg")
                        lock.lock(); tokens.append(token); lock.unlock()
                    } catch { lock.lock(); firstError = error; lock.unlock() }
                }
            }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            if let firstError { self.finish(.failure(firstError)) }
            else if tokens.isEmpty { self.finish(.failure(LocalMediaSelectionError.parsingFailed)) }
            else { self.finish(.success(tokens)) }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        finish(.failure(LocalMediaSelectionError.cancelled))
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        if !expectsVideo {
            guard let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.9) else {
                finish(.failure(LocalMediaSelectionError.parsingFailed))
                return
            }
            do {
                let token = try LocalMediaTokenStore.persist(data: data, fileExtension: "jpg")
                finish(.success([token]))
            } catch {
                finish(.failure(error))
            }
            return
        }
        guard let url = info[.mediaURL] as? URL else {
            finish(.failure(LocalMediaSelectionError.parsingFailed))
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let token = try LocalMediaTokenStore.persist(data: data, fileExtension: url.pathExtension.isEmpty ? "mov" : url.pathExtension)
            finish(.success([token]))
        } catch {
            finish(.failure(error))
        }
    }

    private func finish(_ result: Result<[String], Error>) {
        let callback = completion
        completion = nil
        expectsVideo = false
        callback?(result)
    }
}
