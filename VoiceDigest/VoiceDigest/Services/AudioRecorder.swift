import AVFoundation
import Foundation

enum AudioRecorderError: Error, LocalizedError {
    case permissionDenied
    case recordingFailed
    case audioSessionSetupFailed
    case fileCreationFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access was denied. Please enable it in Settings."
        case .recordingFailed:
            return "Failed to start recording. Please try again."
        case .audioSessionSetupFailed:
            return "Failed to set up audio session."
        case .fileCreationFailed:
            return "Failed to create audio file."
        }
    }
}

@Observable
final class AudioRecorder: NSObject {
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession?

    var isRecording = false
    var recordingDuration: TimeInterval = 0
    var currentFileName: String?

    private var recordingTimer: Timer?
    private var recordingStartTime: Date?

    override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession?.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession?.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    var hasPermission: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    func startRecording() throws -> String {
        guard hasPermission else {
            throw AudioRecorderError.permissionDenied
        }

        let fileName = "\(UUID().uuidString).m4a"
        let audioURL = getDocumentsDirectory().appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            try audioSession?.setActive(true)
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true

            guard audioRecorder?.record() == true else {
                throw AudioRecorderError.recordingFailed
            }

            currentFileName = fileName
            isRecording = true
            recordingStartTime = Date()
            recordingDuration = 0

            // Start timer to update duration
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let startTime = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }

            return fileName
        } catch {
            throw AudioRecorderError.recordingFailed
        }
    }

    func stopRecording() -> (fileName: String?, duration: TimeInterval) {
        recordingTimer?.invalidate()
        recordingTimer = nil

        let duration = recordingDuration
        let fileName = currentFileName

        audioRecorder?.stop()
        isRecording = false

        return (fileName, duration)
    }

    func cancelRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        if let fileName = currentFileName {
            deleteAudioFile(named: fileName)
        }

        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        currentFileName = nil
        recordingDuration = 0
    }

    func deleteAudioFile(named fileName: String) {
        let audioURL = getDocumentsDirectory().appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: audioURL)
    }

    func getAudioURL(for fileName: String) -> URL {
        getDocumentsDirectory().appendingPathComponent(fileName)
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func getAudioLevel() -> Float {
        guard isRecording else { return 0 }
        audioRecorder?.updateMeters()
        let level = audioRecorder?.averagePower(forChannel: 0) ?? -160
        // Normalize from -160...0 to 0...1
        return max(0, (level + 50) / 50)
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording finished unsuccessfully")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Recording encode error: \(error?.localizedDescription ?? "unknown")")
    }
}
