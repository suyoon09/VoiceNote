import Foundation
import Speech

enum SpeechRecognizerError: Error, LocalizedError {
    case permissionDenied
    case recognitionFailed
    case notAvailable
    case noSpeechDetected
    case audioFileNotFound

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

        return try await withCheckedThrowingContinuation { continuation in
            isProcessing = true

            let request = SFSpeechURLRecognitionRequest(url: audioFileURL)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

            // Add task quality hint for better accuracy
            if #available(iOS 16.0, *) {
                request.addsPunctuation = true
            }

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                defer {
                    DispatchQueue.main.async {
                        self?.isProcessing = false
                    }
                }

                if let error = error {
                    let nsError = error as NSError
                    // Check if it's a "no speech detected" error
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                        continuation.resume(throwing: SpeechRecognizerError.noSpeechDetected)
                    } else {
                        continuation.resume(throwing: SpeechRecognizerError.recognitionFailed)
                    }
                    return
                }

                guard let result = result else {
                    continuation.resume(throwing: SpeechRecognizerError.recognitionFailed)
                    return
                }

                if result.isFinal {
                    let transcript = result.bestTranscription.formattedString
                    if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        continuation.resume(throwing: SpeechRecognizerError.noSpeechDetected)
                    } else {
                        continuation.resume(returning: transcript)
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
