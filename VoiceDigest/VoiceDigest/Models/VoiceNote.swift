import Foundation

// MARK: - Note Category

enum NoteCategory: String, Codable, CaseIterable, Identifiable {
    case event = "Event"
    case task = "Task"
    case note = "Note"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .event: return "calendar"
        case .task: return "checkmark.circle"
        case .note: return "note.text"
        }
    }

    var emoji: String {
        switch self {
        case .event: return "📅"
        case .task: return "✅"
        case .note: return "📝"
        }
    }

    var color: String {
        switch self {
        case .event: return "purple"
        case .task: return "orange"
        case .note: return "blue"
        }
    }
}

// MARK: - Voice Note

struct VoiceNote: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    var audioFileName: String
    var rawTranscript: String
    var cleanedContent: String
    var keywords: [String]
    var category: NoteCategory
    var isProcessed: Bool
    var duration: TimeInterval
    var actionableDate: Date?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        audioFileName: String,
        rawTranscript: String = "",
        cleanedContent: String = "",
        keywords: [String] = [],
        category: NoteCategory = .note,
        isProcessed: Bool = false,
        duration: TimeInterval = 0,
        actionableDate: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.audioFileName = audioFileName
        self.rawTranscript = rawTranscript
        self.cleanedContent = cleanedContent
        self.keywords = keywords
        self.category = category
        self.isProcessed = isProcessed
        self.duration = duration
        self.actionableDate = actionableDate
    }

    var hasActionableDate: Bool {
        actionableDate != nil
    }

    var formattedActionableDate: String? {
        guard let date = actionableDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var timeOfDay: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: createdAt)
        switch hour {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<21:
            return .evening
        default:
            return .night
        }
    }

    static func == (lhs: VoiceNote, rhs: VoiceNote) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Time of Day

enum TimeOfDay: String, CaseIterable, Identifiable {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"
    case night = "Night"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var timeRange: String {
        switch self {
        case .morning: return "5 AM - 12 PM"
        case .afternoon: return "12 PM - 5 PM"
        case .evening: return "5 PM - 9 PM"
        case .night: return "9 PM - 5 AM"
        }
    }
}

// MARK: - Daily Digest

struct DailyDigest: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    var notes: [VoiceNote]
    var summary: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        notes: [VoiceNote] = [],
        summary: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.notes = notes
        self.summary = summary
        self.createdAt = createdAt
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var noteCount: Int {
        notes.count
    }

    var notesByCategory: [NoteCategory: [VoiceNote]] {
        Dictionary(grouping: notes, by: { $0.category })
    }

    var notesByTimeOfDay: [TimeOfDay: [VoiceNote]] {
        Dictionary(grouping: notes, by: { $0.timeOfDay })
    }

    var topKeywords: [String] {
        let allKeywords = notes.flatMap { $0.keywords }
        let keywordCounts = Dictionary(grouping: allKeywords, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        return Array(keywordCounts.prefix(5).map { $0.key })
    }

    static func == (lhs: DailyDigest, rhs: DailyDigest) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - App Statistics

struct AppStatistics: Codable {
    var totalNotes: Int
    var totalDigests: Int
    var totalRecordingTime: TimeInterval
    var categoryCounts: [String: Int]

    init(
        totalNotes: Int = 0,
        totalDigests: Int = 0,
        totalRecordingTime: TimeInterval = 0,
        categoryCounts: [String: Int] = [:]
    ) {
        self.totalNotes = totalNotes
        self.totalDigests = totalDigests
        self.totalRecordingTime = totalRecordingTime
        self.categoryCounts = categoryCounts
    }

    var formattedRecordingTime: String {
        let hours = Int(totalRecordingTime) / 3600
        let minutes = (Int(totalRecordingTime) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
}
