import AVFoundation
import Foundation

struct LocalVoiceRecording {
    let token: String
    let duration: TimeInterval
}

enum VoiceServiceError: LocalizedError {
    case permissionDenied
    case notRecording
    case tooShort
    case invalidFile

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Microphone access is required to record a voice message."
        case .notRecording: return "Recording is no longer active."
        case .tooShort: return "Hold a little longer to send a voice message."
        case .invalidFile: return "The local recording could not be played."
        }
    }
}

@MainActor
final class LocalVoiceRecorderService: NSObject, AVAudioRecorderDelegate {
    static let shared = LocalVoiceRecorderService()
    private var recorder: AVAudioRecorder?
    private var startedAt: Date?
    private var maxTimer: Timer?
    private var completion: ((Result<LocalVoiceRecording, Error>) -> Void)?
    private var cancelPending = false

    func begin(onFinished: @escaping (Result<LocalVoiceRecording, Error>) -> Void, completion: @escaping (Result<Void, Error>) -> Void) {
        cancelPending = false
        finishHandler = onFinished
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] allowed in
            DispatchQueue.main.async {
                guard let self else { return }
                guard !self.cancelPending else { return }
                guard allowed else { self.finishHandler = nil; completion(.failure(VoiceServiceError.permissionDenied)); return }
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                    try session.setActive(true, options: .notifyOthersOnDeactivation)
                    let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("KinvaMedia", isDirectory: true)
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    let url = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
                    let settings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
                    let recorder = try AVAudioRecorder(url: url, settings: settings)
                    recorder.delegate = self
                    recorder.isMeteringEnabled = true
                    guard recorder.record() else { throw VoiceServiceError.invalidFile }
                    self.recorder = recorder
                    self.startedAt = Date()
                    self.maxTimer?.invalidate()
                    self.maxTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in self?.end(cancelled: false, completion: nil) }
                    completion(.success(()))
                } catch { completion(.failure(error)) }
            }
        }
    }

    private var finishHandler: ((Result<LocalVoiceRecording, Error>) -> Void)?

    func end(cancelled: Bool, completion: ((Result<LocalVoiceRecording, Error>) -> Void)?) {
        maxTimer?.invalidate(); maxTimer = nil
        guard let recorder, let startedAt else { cancelPending = cancelled; completion?(.failure(VoiceServiceError.notRecording)); return }
        self.completion = completion
        let duration = Date().timeIntervalSince(startedAt)
        self.recorder = nil; self.startedAt = nil
        recorder.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let callback = completion ?? finishHandler
        finishHandler = nil
        guard !cancelled else { try? FileManager.default.removeItem(at: recorder.url); self.completion = nil; return }
        guard duration >= 1 else { try? FileManager.default.removeItem(at: recorder.url); self.completion = nil; callback?(.failure(VoiceServiceError.tooShort)); return }
        callback?(.success(LocalVoiceRecording(token: recorder.url.path, duration: duration)))
        self.completion = nil
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag { completion?(.failure(VoiceServiceError.invalidFile)); completion = nil }
    }
}

@MainActor
final class LocalVoicePlayer: NSObject, AVAudioPlayerDelegate {
    static let shared = LocalVoicePlayer()
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var progressHandler: ((Float) -> Void)?
    var onPlaybackStateChanged: ((String?, Bool) -> Void)?

    func toggle(token: String, progress: ((Float) -> Void)? = nil) -> Bool {
        guard FileManager.default.fileExists(atPath: token) else { return false }
        if let player, let url = player.url, url.path == token {
            if player.isPlaying {
                player.pause()
                onPlaybackStateChanged?(token, false)
            } else {
                player.play()
                onPlaybackStateChanged?(token, true)
            }
            return player.isPlaying
        }
        stop()
        do {
            let next = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: token))
            next.delegate = self; next.prepareToPlay(); next.play()
            player = next; progressHandler = progress
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in self?.tick() }
            onPlaybackStateChanged?(token, true)
            return true
        } catch { stop() }
        return false
    }

    func stop() {
        let token = player?.url?.path
        progressHandler?(0)
        player?.stop()
        player = nil
        timer?.invalidate()
        timer = nil
        progressHandler = nil
        onPlaybackStateChanged?(token, false)
    }
    private func tick() { guard let player else { return }; progressHandler?(Float(player.currentTime / max(player.duration, 0.01))) }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { stop() }
}
