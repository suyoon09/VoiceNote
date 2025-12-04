import Foundation
import SwiftUI
import UserNotifications
import EventKit

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
    case addedToCalendar
    case calendarPermissionDenied
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
        case .addedToCalendar:
            return "Added to calendar"
        case .calendarPermissionDenied:
            return "Calendar access denied"
        case .error(let message):
            return message
        }
    }

    var icon: String {
        switch self {
        case .recordingTooShort, .noSpeechDetected, .error, .calendarPermissionDenied:
            return "exclamationmark.circle"
        case .noteSaved, .digestGenerated, .addedToCalendar:
            return "checkmark.circle"
        case .noteDeleted:
            return "trash"
        }
    }

    var isError: Bool {
        switch self {
        case .recordingTooShort, .noSpeechDetected, .error, .calendarPermissionDenied:
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
    let eventStore = EKEventStore()

    // MARK: - State

    var recordingState: RecordingState = .idle
    var voiceNotes: [VoiceNote] = []
    var dailyDigests: [DailyDigest] = []
    var statistics: AppStatistics = AppStatistics()
    var hasCalendarPermission = false

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
    private let notesFileName = "voiceNotes.json"
    private let digestsFileName = "dailyDigests.json"
    private let statisticsFileName = "appStatistics.json"
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
        await requestCalendarPermission()
    }

    var hasMicrophonePermission: Bool {
        audioRecorder.hasPermission
    }

    var hasSpeechPermission: Bool {
        speechRecognizer.hasPermission
    }

    func requestCalendarPermission() async {
        if #available(iOS 17.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    hasCalendarPermission = granted
                }
            } catch {
                await MainActor.run {
                    hasCalendarPermission = false
                }
            }
        } else {
            let granted = await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
            await MainActor.run {
                hasCalendarPermission = granted
            }
        }
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
            let actionableDate = textProcessor.extractActionableDate(from: rawTranscript)

            // Create note
            let note = VoiceNote(
                audioFileName: fileName,
                rawTranscript: rawTranscript,
                cleanedContent: cleanedContent,
                keywords: keywords,
                category: category,
                isProcessed: true,
                duration: duration,
                actionableDate: actionableDate
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

    // MARK: - Calendar Integration

    func addToCalendar(note: VoiceNote) {
        guard hasCalendarPermission else {
            showToast(message: .calendarPermissionDenied)
            return
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = textProcessor.abridgeContent(note.cleanedContent)

        // Use actionable date if available, otherwise use 1 hour from now
        if let actionableDate = note.actionableDate {
            event.startDate = actionableDate
            event.endDate = actionableDate.addingTimeInterval(3600) // 1 hour duration
        } else {
            let startDate = Date().addingTimeInterval(3600)
            event.startDate = startDate
            event.endDate = startDate.addingTimeInterval(3600)
        }

        event.notes = note.cleanedContent
        event.calendar = eventStore.defaultCalendarForNewEvents

        // Add a reminder 15 minutes before
        let alarm = EKAlarm(relativeOffset: -900)
        event.addAlarm(alarm)

        do {
            try eventStore.save(event, span: .thisEvent)
            showToast(message: .addedToCalendar)
        } catch {
            showToast(message: .error("Failed to add to calendar"))
        }
    }

    func addToCalendarWithDate(note: VoiceNote, date: Date) {
        guard hasCalendarPermission else {
            showToast(message: .calendarPermissionDenied)
            return
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = textProcessor.abridgeContent(note.cleanedContent)
        event.startDate = date
        event.endDate = date.addingTimeInterval(3600)
        event.notes = note.cleanedContent
        event.calendar = eventStore.defaultCalendarForNewEvents

        let alarm = EKAlarm(relativeOffset: -900)
        event.addAlarm(alarm)

        do {
            try eventStore.save(event, span: .thisEvent)
            showToast(message: .addedToCalendar)
        } catch {
            showToast(message: .error("Failed to add to calendar"))
        }
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

    // MARK: - Persistence (FileManager with Atomic Writes)

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func fileURL(for fileName: String) -> URL {
        documentsDirectory.appendingPathComponent(fileName)
    }

    private func loadData() {
        loadNotes()
        loadDigests()
        loadStatistics()
    }

    private func loadNotes() {
        let url = fileURL(for: notesFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([VoiceNote].self, from: data)
            voiceNotes = decoded
        } catch {
            print("Failed to load notes: \(error)")
        }
    }

    private func saveNotes() {
        let url = fileURL(for: notesFileName)
        do {
            let data = try JSONEncoder().encode(voiceNotes)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save notes: \(error)")
        }
    }

    private func loadDigests() {
        let url = fileURL(for: digestsFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([DailyDigest].self, from: data)
            dailyDigests = decoded
        } catch {
            print("Failed to load digests: \(error)")
        }
    }

    private func saveDigests() {
        let url = fileURL(for: digestsFileName)
        do {
            let data = try JSONEncoder().encode(dailyDigests)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save digests: \(error)")
        }
    }

    private func loadStatistics() {
        let url = fileURL(for: statisticsFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(AppStatistics.self, from: data)
            statistics = decoded
        } catch {
            print("Failed to load statistics: \(error)")
        }
    }

    private func saveStatistics() {
        let url = fileURL(for: statisticsFileName)
        do {
            let data = try JSONEncoder().encode(statistics)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save statistics: \(error)")
        }
    }

    private func loadSettings() {
        // Keep digest notification time in UserDefaults (small, simple preference)
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
