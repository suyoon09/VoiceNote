import Foundation
import SwiftUI
import UserNotifications

enum RecordingState {
    case idle
    case recording
    case processing
    case error(String)
}

enum ToastMessage: Equatable {
    case recordingTooShort
    case noSpeechDetected
    case noteSaved
    case noteDeleted
    case digestGenerated
    case error(String)

    var message: String {
        switch self {
        case .recordingTooShort:
            return "Recording too short"
        case .noSpeechDetected:
            return "No speech detected"
        case .noteSaved:
            return "Note saved"
        case .noteDeleted:
            return "Note deleted"
        case .digestGenerated:
            return "Digest generated"
        case .error(let message):
            return message
        }
    }

    var icon: String {
        switch self {
        case .recordingTooShort, .noSpeechDetected, .error:
            return "exclamationmark.circle"
        case .noteSaved, .digestGenerated:
            return "checkmark.circle"
        case .noteDeleted:
            return "trash"
        }
    }

    var isError: Bool {
        switch self {
        case .recordingTooShort, .noSpeechDetected, .error:
            return true
        default:
            return false
        }
    }
}

@Observable
final class VoiceNoteManager {
    // MARK: - Services

    let audioRecorder = AudioRecorder()
    let speechRecognizer = SpeechRecognizer()
    let textProcessor = TextProcessor()

    // MARK: - State

    var recordingState: RecordingState = .idle
    var voiceNotes: [VoiceNote] = []
    var dailyDigests: [DailyDigest] = []
    var statistics: AppStatistics = AppStatistics()

    var toastMessage: ToastMessage?
    var showToast = false

    // MARK: - Settings

    var digestNotificationTime: Date {
        didSet {
            saveDigestNotificationTime()
            scheduleDigestNotification()
        }
    }

    // MARK: - Constants

    private let minimumRecordingDuration: TimeInterval = 2.0
    private let notesKey = "voiceNotes"
    private let digestsKey = "dailyDigests"
    private let statisticsKey = "appStatistics"
    private let digestTimeKey = "digestNotificationTime"

    // MARK: - Computed Properties

    var isRecording: Bool {
        if case .recording = recordingState {
            return true
        }
        return false
    }

    var isProcessing: Bool {
        if case .processing = recordingState {
            return true
        }
        return false
    }

    var recordingDuration: TimeInterval {
        audioRecorder.recordingDuration
    }

    var todaysNotes: [VoiceNote] {
        let calendar = Calendar.current
        return voiceNotes.filter { calendar.isDateInToday($0.createdAt) }
    }

    var todaysNoteCount: Int {
        todaysNotes.count
    }

    // MARK: - Initialization

    init() {
        // Set default digest time to 9 PM
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 21
        components.minute = 0
        self.digestNotificationTime = calendar.date(from: components) ?? Date()

        loadData()
        loadSettings()
    }

    // MARK: - Permissions

    func requestPermissions() async {
        _ = await audioRecorder.requestPermission()
        _ = await speechRecognizer.requestPermission()
        await requestNotificationPermission()
    }

    var hasMicrophonePermission: Bool {
        audioRecorder.hasPermission
    }

    var hasSpeechPermission: Bool {
        speechRecognizer.hasPermission
    }

    // MARK: - Recording

    func startRecording() {
        guard case .idle = recordingState else { return }

        do {
            _ = try audioRecorder.startRecording()
            recordingState = .recording

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        } catch {
            showToast(message: .error(error.localizedDescription))
        }
    }

    func stopRecording() {
        guard case .recording = recordingState else { return }

        let (fileName, duration) = audioRecorder.stopRecording()

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Check minimum duration
        guard duration >= minimumRecordingDuration else {
            if let fileName = fileName {
                audioRecorder.deleteAudioFile(named: fileName)
            }
            recordingState = .idle
            showToast(message: .recordingTooShort)
            return
        }

        guard let fileName = fileName else {
            recordingState = .idle
            showToast(message: .error("Failed to save recording"))
            return
        }

        // Process the recording
        Task {
            await processRecording(fileName: fileName, duration: duration)
        }
    }

    func cancelRecording() {
        audioRecorder.cancelRecording()
        recordingState = .idle
    }

    // MARK: - Processing

    private func processRecording(fileName: String, duration: TimeInterval) async {
        await MainActor.run {
            recordingState = .processing
        }

        let audioURL = audioRecorder.getAudioURL(for: fileName)

        do {
            // Transcribe
            let rawTranscript = try await speechRecognizer.transcribe(audioFileURL: audioURL)

            // Validate content
            guard textProcessor.hasValidContent(rawTranscript) else {
                audioRecorder.deleteAudioFile(named: fileName)
                await MainActor.run {
                    recordingState = .idle
                    showToast(message: .noSpeechDetected)
                }
                return
            }

            // Process transcript
            let cleanedContent = textProcessor.cleanTranscript(rawTranscript)
            let keywords = textProcessor.extractKeywords(from: rawTranscript)
            let category = textProcessor.categorize(rawTranscript)

            // Create note
            let note = VoiceNote(
                audioFileName: fileName,
                rawTranscript: rawTranscript,
                cleanedContent: cleanedContent,
                keywords: keywords,
                category: category,
                isProcessed: true,
                duration: duration
            )

            await MainActor.run {
                voiceNotes.insert(note, at: 0)
                updateStatistics(newNote: note)
                saveNotes()
                recordingState = .idle
                showToast(message: .noteSaved)
            }

        } catch let error as SpeechRecognizerError {
            audioRecorder.deleteAudioFile(named: fileName)
            await MainActor.run {
                recordingState = .idle
                if error == .noSpeechDetected || error == .timeout {
                    showToast(message: .noSpeechDetected)
                } else {
                    showToast(message: .error(error.localizedDescription))
                }
            }
        } catch {
            audioRecorder.deleteAudioFile(named: fileName)
            await MainActor.run {
                recordingState = .idle
                showToast(message: .error("Failed to process recording"))
            }
        }
    }

    // MARK: - Note Management

    func deleteNote(_ note: VoiceNote) {
        audioRecorder.deleteAudioFile(named: note.audioFileName)
        voiceNotes.removeAll { $0.id == note.id }
        saveNotes()
        showToast(message: .noteDeleted)
    }

    func deleteNote(at offsets: IndexSet) {
        for index in offsets {
            let note = voiceNotes[index]
            audioRecorder.deleteAudioFile(named: note.audioFileName)
        }
        voiceNotes.remove(atOffsets: offsets)
        saveNotes()
        showToast(message: .noteDeleted)
    }

    // MARK: - Digest Generation

    func generateDigest(for notes: [VoiceNote]? = nil) -> DailyDigest {
        let notesToDigest = notes ?? todaysNotes
        let summary = textProcessor.generateDigestSummary(for: notesToDigest)

        let digest = DailyDigest(
            date: Date(),
            notes: notesToDigest,
            summary: summary
        )

        // Check if we already have a digest for today
        let calendar = Calendar.current
        if let existingIndex = dailyDigests.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: Date()) }) {
            dailyDigests[existingIndex] = digest
        } else {
            dailyDigests.insert(digest, at: 0)
            statistics.totalDigests += 1
        }

        saveDigests()
        saveStatistics()
        showToast(message: .digestGenerated)

        return digest
    }

    func generateReportNow() -> DailyDigest {
        return generateDigest(for: todaysNotes)
    }

    // MARK: - Toast

    func showToast(message: ToastMessage) {
        toastMessage = message
        showToast = true

        // Auto-hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.showToast = false
        }
    }

    // MARK: - Statistics

    private func updateStatistics(newNote: VoiceNote) {
        statistics.totalNotes += 1
        statistics.totalRecordingTime += newNote.duration
        statistics.categoryCounts[newNote.category.rawValue, default: 0] += 1
        saveStatistics()
    }

    // MARK: - Notifications

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification permission error: \(error)")
        }
    }

    func scheduleDigestNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["dailyDigest"])

        let content = UNMutableNotificationContent()
        content.title = "Daily Digest Ready"
        content.body = "Your voice notes from today are ready to review."
        content.sound = .default

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: digestNotificationTime)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyDigest", content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    // MARK: - Persistence

    private func loadData() {
        loadNotes()
        loadDigests()
        loadStatistics()
    }

    private func loadNotes() {
        if let data = UserDefaults.standard.data(forKey: notesKey),
           let decoded = try? JSONDecoder().decode([VoiceNote].self, from: data) {
            voiceNotes = decoded
        }
    }

    private func saveNotes() {
        if let encoded = try? JSONEncoder().encode(voiceNotes) {
            UserDefaults.standard.set(encoded, forKey: notesKey)
        }
    }

    private func loadDigests() {
        if let data = UserDefaults.standard.data(forKey: digestsKey),
           let decoded = try? JSONDecoder().decode([DailyDigest].self, from: data) {
            dailyDigests = decoded
        }
    }

    private func saveDigests() {
        if let encoded = try? JSONEncoder().encode(dailyDigests) {
            UserDefaults.standard.set(encoded, forKey: digestsKey)
        }
    }

    private func loadStatistics() {
        if let data = UserDefaults.standard.data(forKey: statisticsKey),
           let decoded = try? JSONDecoder().decode(AppStatistics.self, from: data) {
            statistics = decoded
        }
    }

    private func saveStatistics() {
        if let encoded = try? JSONEncoder().encode(statistics) {
            UserDefaults.standard.set(encoded, forKey: statisticsKey)
        }
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: digestTimeKey),
           let decoded = try? JSONDecoder().decode(Date.self, from: data) {
            digestNotificationTime = decoded
        }
    }

    private func saveDigestNotificationTime() {
        if let encoded = try? JSONEncoder().encode(digestNotificationTime) {
            UserDefaults.standard.set(encoded, forKey: digestTimeKey)
        }
    }
}
