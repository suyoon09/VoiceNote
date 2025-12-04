import Foundation
import Speech

enum SpeechRecognizerError: Error, LocalizedError {
    case permissionDenied
    case recognitionFailed
    case notAvailable
    case noSpeechDetected
    case audioFileNotFound
    case timeout

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Speech recognition permission was denied. Please enable it in Settings."
        case .recognitionFailed:
            return "Speech recognition failed. Please try again."
        case .notAvailable:
            return "Speech recognition is not available on this device."
        case .noSpeechDetected:
            return "No speech was detected in the recording."
        case .audioFileNotFound:
            return "Audio file not found."
        case .timeout:
            return "Recognition timed out. No speech detected."
        }
    }
}

@Observable
final class SpeechRecognizer {
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    var isProcessing = false
    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private let transcriptionTimeout: TimeInterval = 10.0

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.supportsOnDeviceRecognition = true
        updateAuthorizationStatus()
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    var hasPermission: Bool {
        authorizationStatus == .authorized
    }

    private func updateAuthorizationStatus() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    func transcribe(audioFileURL: URL) async throws -> String {
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            throw SpeechRecognizerError.audioFileNotFound
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechRecognizerError.notAvailable
        }

        guard hasPermission else {
            throw SpeechRecognizerError.permissionDenied
        }

        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await self.performTranscription(recognizer: recognizer, audioFileURL: audioFileURL)
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.transcriptionTimeout * 1_000_000_000))
                throw SpeechRecognizerError.timeout
            }

            guard let result = try await group.next() else {
                throw SpeechRecognizerError.recognitionFailed
            }

            group.cancelAll()
            return result
        }
    }

    private func performTranscription(recognizer: SFSpeechRecognizer, audioFileURL: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                self.isProcessing = true
            }

            let request = SFSpeechURLRecognitionRequest(url: audioFileURL)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

            if #available(iOS 16.0, *) {
                request.addsPunctuation = true
            }

            var hasResumed = false
            let resumeOnce: (Result<String, Error>) -> Void = { result in
                guard !hasResumed else { return }
                hasResumed = true
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                        resumeOnce(.failure(SpeechRecognizerError.noSpeechDetected))
                    } else if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1101 {
                        resumeOnce(.failure(SpeechRecognizerError.noSpeechDetected))
                    } else {
                        resumeOnce(.failure(SpeechRecognizerError.recognitionFailed))
                    }
                    return
                }

                guard let result = result else {
                    resumeOnce(.failure(SpeechRecognizerError.recognitionFailed))
                    return
                }

                if result.isFinal {
                    let transcript = result.bestTranscription.formattedString
                    if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        resumeOnce(.failure(SpeechRecognizerError.noSpeechDetected))
                    } else {
                        resumeOnce(.success(transcript))
                    }
                }
            }
        }
    }

    func cancelTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
        isProcessing = false
    }

    var authorizationStatusDescription: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Not Determined"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .authorized:
            return "Authorized"
        @unknown default:
            return "Unknown"
        }
    }

    var isOnDeviceRecognitionAvailable: Bool {
        speechRecognizer?.supportsOnDeviceRecognition ?? false
    }
}
