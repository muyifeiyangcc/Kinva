import AVFoundation
import Photos
import UIKit

enum LocalMediaPermissionService {
    static func requestPhotoAccess(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { state in DispatchQueue.main.async { completion(state == .authorized || state == .limited) } }
    }
    static func requestCamera(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { allowed in DispatchQueue.main.async { completion(allowed) } }
    }
    static func requestMicrophone(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { allowed in
            DispatchQueue.main.async { completion(allowed) }
        }
    }
}
