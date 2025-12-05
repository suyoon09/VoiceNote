import Foundation
import EventKit

final class CalendarService {
    // MARK: - Properties

    private let eventStore = EKEventStore()
    private(set) var hasPermission = false

    // MARK: - Permission Handling

    func requestPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    hasPermission = granted
                }
                return granted
            } catch {
                await MainActor.run {
                    hasPermission = false
                }
                return false
            }
        } else {
            let granted = await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
            await MainActor.run {
                hasPermission = granted
            }
            return granted
        }
    }

    func checkPermissionStatus() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized, .fullAccess:
            hasPermission = true
            return true
        default:
            hasPermission = false
            return false
        }
    }

    // MARK: - Date Detection

    func detectDate(in text: String) -> Date? {
        let detector: NSDataDetector
        do {
            detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        } catch {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        var foundDate: Date?
        var hasTimeComponent = false

        detector.enumerateMatches(in: text, options: [], range: range) { result, _, stop in
            guard let result = result, let date = result.date else { return }

            // Only consider future dates or dates within the last hour
            let now = Date()
            let oneHourAgo = now.addingTimeInterval(-3600)

            if date >= oneHourAgo {
                // Check if this result includes time information
                let matchedRange = Range(result.range, in: text)
                let matchedText = matchedRange.map { String(text[$0]).lowercased() } ?? ""

                let currentHasTime = result.timeZone != nil ||
                    matchedText.contains("at ") ||
                    matchedText.contains("am") ||
                    matchedText.contains("pm") ||
                    matchedText.contains("o'clock")

                // Prefer dates with time components
                if foundDate == nil || (currentHasTime && !hasTimeComponent) {
                    foundDate = date
                    hasTimeComponent = currentHasTime
                    if currentHasTime {
                        stop.pointee = true
                    }
                }
            }
        }

        // If we found a date without a specific time, set it to 9 AM
        if let date = foundDate, !hasTimeComponent {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: date)
            if components.hour == 0 && components.minute == 0 {
                var newComponents = calendar.dateComponents([.year, .month, .day], from: date)
                newComponents.hour = 9
                newComponents.minute = 0
                return calendar.date(from: newComponents)
            }
        }

        return foundDate
    }

    // MARK: - Event Creation

    @discardableResult
    func createEvent(title: String, notes: String?, date: Date, duration: TimeInterval = 3600) -> Bool {
        guard hasPermission else { return false }

        let event = EKEvent(eventStore: eventStore)
        event.title = "VoiceDigest: \(title)"
        event.startDate = date
        event.endDate = date.addingTimeInterval(duration)
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents

        // Add a reminder 15 minutes before
        let alarm = EKAlarm(relativeOffset: -900)
        event.addAlarm(alarm)

        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }

    func createEventFromNote(_ note: VoiceNote, useDetectedDate: Bool = true) -> Bool {
        guard hasPermission else { return false }

        // Determine the date to use
        let eventDate: Date
        if useDetectedDate, let detectedDate = note.actionableDate {
            eventDate = detectedDate
        } else if useDetectedDate, let detectedDate = detectDate(in: note.cleanedContent) {
            eventDate = detectedDate
        } else {
            // Fallback to note creation date + 1 hour
            eventDate = note.createdAt.addingTimeInterval(3600)
        }

        // Create a concise title from the content
        let title = createEventTitle(from: note.cleanedContent)

        return createEvent(
            title: title,
            notes: note.cleanedContent,
            date: eventDate
        )
    }

    // MARK: - Auto-Sync

    func autoSyncIfDateDetected(_ note: VoiceNote) -> Bool {
        // Only sync if a date was detected in the note
        guard note.actionableDate != nil || detectDate(in: note.cleanedContent) != nil else {
            return false
        }

        return createEventFromNote(note, useDetectedDate: true)
    }

    // MARK: - Helpers

    private func createEventTitle(from content: String) -> String {
        // Take first meaningful part of the content
        let words = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        let maxWords = 6
        let titleWords = Array(words.prefix(maxWords))
        var title = titleWords.joined(separator: " ")

        if words.count > maxWords {
            title += "..."
        }

        // Capitalize first letter
        if let first = title.first {
            title = first.uppercased() + title.dropFirst()
        }

        return title.isEmpty ? "Voice Note" : title
    }
}
