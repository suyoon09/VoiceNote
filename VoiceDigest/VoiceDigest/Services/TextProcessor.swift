import Foundation
import NaturalLanguage

final class TextProcessor {
    // MARK: - Filler Words

    private static let fillerWords: Set<String> = [
        "um", "uh", "uhh", "umm", "er", "err", "ah", "ahh",
        "like", "you know", "i mean", "so", "basically",
        "actually", "literally", "anyway", "anyways",
        "right", "okay", "ok", "well", "yeah", "yea",
        "kind of", "kinda", "sort of", "sorta",
        "just", "really", "very", "pretty much"
    ]

    // MARK: - Removable Phrases for Abridging

    private static let removablePhrases: [String] = [
        "i need to", "i have to", "i should", "i must", "i want to",
        "i'm going to", "i will", "i'll", "gonna", "going to",
        "need to", "have to", "should", "must", "want to",
        "remember to", "don't forget to", "make sure to",
        "i think", "i believe", "i feel like",
        "it would be good to", "it might be good to",
        "probably should", "maybe i should",
        "for some", "do some", "get some", "buy some",
        "about the", "regarding the", "concerning the",
        "in order to", "so that i can", "so i can"
    ]

    // MARK: - Action Words Mapping

    private static let actionMappings: [String: String] = [
        "groceries": "Groceries",
        "grocery": "Groceries",
        "shopping": "Shopping",
        "buy": "Buy",
        "pick up": "Pick up",
        "call": "Call",
        "email": "Email",
        "text": "Text",
        "message": "Message",
        "meet": "Meet",
        "meeting": "Meeting",
        "schedule": "Schedule",
        "book": "Book",
        "finish": "Finish",
        "complete": "Complete",
        "send": "Send",
        "check": "Check",
        "review": "Review",
        "prepare": "Prepare",
        "fix": "Fix",
        "clean": "Clean",
        "organize": "Organize",
        "pay": "Pay",
        "return": "Return"
    ]

    // MARK: - Category Keywords

    private static let categoryKeywords: [NoteCategory: Set<String>] = [
        .work: Set([
            "meeting", "meetings", "project", "projects", "deadline", "deadlines",
            "email", "emails", "client", "clients", "boss", "office",
            "presentation", "presentations", "report", "reports", "team",
            "colleague", "colleagues", "schedule", "conference", "budget",
            "work", "job", "manager", "employee", "company", "business",
            "call", "calls", "memo", "agenda", "proposal", "contract",
            "stakeholder", "deliverable", "milestone", "review"
        ]),
        .tasks: Set([
            "need to", "have to", "must", "should", "remember",
            "don't forget", "buy", "call", "send", "finish",
            "complete", "todo", "to-do", "remind", "reminder",
            "pick up", "drop off", "schedule", "book", "make",
            "get", "grab", "return", "pay", "submit", "fix",
            "clean", "organize", "prepare", "check", "update"
        ]),
        .ideas: Set([
            "idea", "ideas", "what if", "maybe", "could",
            "might", "think about", "consider", "concept",
            "imagine", "create", "build", "invention", "thought",
            "brainstorm", "innovation", "creative", "design",
            "develop", "explore", "experiment", "try", "possible",
            "potential", "inspiration", "vision", "plan"
        ]),
        .personal: Set([
            "family", "friend", "friends", "home", "weekend",
            "vacation", "birthday", "dinner", "lunch", "movie",
            "hobby", "health", "exercise", "doctor", "personal",
            "mom", "dad", "wife", "husband", "kid", "kids",
            "children", "brother", "sister", "party", "date",
            "gym", "workout", "sleep", "relax", "fun",
            "trip", "travel", "holiday", "anniversary", "wedding"
        ])
    ]

    // MARK: - Transcript Cleanup

    func cleanTranscript(_ raw: String) -> String {
        var cleaned = raw.lowercased()

        // Remove filler words (longer phrases first)
        let sortedFillers = Self.fillerWords.sorted { $0.count > $1.count }
        for filler in sortedFillers {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: filler))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    options: [],
                    range: NSRange(cleaned.startIndex..., in: cleaned),
                    withTemplate: ""
                )
            }
        }

        // Clean up multiple spaces
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }

        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleaned.isEmpty {
            cleaned = cleaned.prefix(1).uppercased() + cleaned.dropFirst()
        }

        if !cleaned.isEmpty && !cleaned.hasSuffix(".") && !cleaned.hasSuffix("!") && !cleaned.hasSuffix("?") {
            cleaned += "."
        }

        cleaned = fixCapitalization(cleaned)
        cleaned = fixPunctuation(cleaned)

        return cleaned
    }

    // MARK: - Abridge Content

    func abridgeContent(_ text: String) -> String {
        var abridged = text.lowercased()

        // Remove ending punctuation for processing
        abridged = abridged.trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))

        // Remove common verbose phrases (longer phrases first)
        let sortedPhrases = Self.removablePhrases.sorted { $0.count > $1.count }
        for phrase in sortedPhrases {
            abridged = abridged.replacingOccurrences(of: phrase, with: "")
        }

        // Clean up spaces
        while abridged.contains("  ") {
            abridged = abridged.replacingOccurrences(of: "  ", with: " ")
        }
        abridged = abridged.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to identify action and extract key items
        var action: String?
        var items: [String] = []

        // Check for action words
        for (keyword, actionName) in Self.actionMappings {
            if abridged.contains(keyword) {
                action = actionName
                // Remove the action word from the remaining text
                abridged = abridged.replacingOccurrences(of: keyword, with: "")
                break
            }
        }

        // Clean up again after removing action
        abridged = abridged.trimmingCharacters(in: .whitespacesAndNewlines)
        while abridged.hasPrefix(",") || abridged.hasPrefix("-") {
            abridged = String(abridged.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract items from remaining text (split by commas, "and", etc.)
        let itemPatterns = abridged
            .replacingOccurrences(of: " and ", with: ", ")
            .replacingOccurrences(of: " & ", with: ", ")
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 1 }

        if !itemPatterns.isEmpty {
            items = itemPatterns
        }

        // Build abridged output
        if let action = action {
            if items.isEmpty {
                // Just capitalize and return
                return action.prefix(1).uppercased() + action.dropFirst() + (abridged.isEmpty ? "" : " - \(abridged)")
            } else {
                return "\(action) - \(items.joined(separator: ", "))"
            }
        } else if !items.isEmpty {
            // No clear action, just list items
            let firstItem = items[0]
            let capitalizedFirst = firstItem.prefix(1).uppercased() + firstItem.dropFirst()
            if items.count > 1 {
                return "\(capitalizedFirst), \(items.dropFirst().joined(separator: ", "))"
            }
            return capitalizedFirst
        } else {
            // Fallback: just capitalize first letter
            if abridged.isEmpty {
                return text // Return original if we couldn't abridge
            }
            return abridged.prefix(1).uppercased() + abridged.dropFirst()
        }
    }

    private func fixCapitalization(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: " i ", with: " I ")
        result = result.replacingOccurrences(of: " i'", with: " I'")

        let sentences = result.components(separatedBy: ". ")
        result = sentences.map { sentence in
            guard !sentence.isEmpty else { return sentence }
            return sentence.prefix(1).uppercased() + sentence.dropFirst()
        }.joined(separator: ". ")

        return result
    }

    private func fixPunctuation(_ text: String) -> String {
        var result = text

        let listPattern = "\\b(\\w+)\\s+and\\s+(\\w+)\\s+and\\s+(\\w+)\\b"
        if let regex = try? NSRegularExpression(pattern: listPattern, options: .caseInsensitive) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: "$1, $2, and $3"
            )
        }

        result = result.replacingOccurrences(of: "..", with: ".")
        result = result.replacingOccurrences(of: ",,", with: ",")
        result = result.replacingOccurrences(of: " ,", with: ",")
        result = result.replacingOccurrences(of: " .", with: ".")

        return result
    }

    // MARK: - Categorization

    func categorize(_ text: String) -> NoteCategory {
        let lowercasedText = text.lowercased()
        var categoryScores: [NoteCategory: Int] = [:]

        for (category, keywords) in Self.categoryKeywords {
            var score = 0
            for keyword in keywords {
                if lowercasedText.contains(keyword) {
                    score += keyword.contains(" ") ? 3 : 1
                }
            }
            categoryScores[category] = score
        }

        if let (category, score) = categoryScores.max(by: { $0.value < $1.value }), score > 0 {
            return category
        }

        return .uncategorized
    }

    // MARK: - Keyword Extraction

    func extractKeywords(from text: String, maxKeywords: Int = 10) -> [String] {
        var keywords: Set<String> = []

        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            if let tag = tag {
                let word = String(text[tokenRange]).lowercased()
                guard word.count >= 4 else { return true }
                guard !isCommonWord(word) && !Self.fillerWords.contains(word) else { return true }

                if tag == .noun || tag == .verb || tag == .adjective {
                    keywords.insert(word.capitalized)
                }
            }
            return true
        }

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if let tag = tag {
                let word = String(text[tokenRange])
                if tag == .personalName || tag == .placeName || tag == .organizationName {
                    keywords.insert(word)
                }
            }
            return true
        }

        let sortedKeywords = keywords.sorted { $0.count > $1.count }
        return Array(sortedKeywords.prefix(maxKeywords))
    }

    private func isCommonWord(_ word: String) -> Bool {
        let commonWords: Set<String> = [
            "the", "be", "to", "of", "and", "a", "in", "that", "have", "i",
            "it", "for", "not", "on", "with", "he", "as", "you", "do", "at",
            "this", "but", "his", "by", "from", "they", "we", "say", "her",
            "she", "or", "an", "will", "my", "one", "all", "would", "there",
            "their", "what", "so", "up", "out", "if", "about", "who", "get",
            "which", "go", "me", "when", "make", "can", "time", "no", "just",
            "him", "know", "take", "people", "into", "year", "your", "good",
            "some", "could", "them", "see", "other", "than", "then", "now",
            "look", "only", "come", "its", "over", "think", "also", "back",
            "after", "use", "two", "how", "our", "work", "first", "well",
            "way", "even", "new", "want", "because", "any", "these", "give",
            "day", "most", "us", "very", "need", "going", "been", "thing"
        ]
        return commonWords.contains(word)
    }

    // MARK: - Content Validation

    func hasValidContent(_ transcript: String) -> Bool {
        let cleaned = transcript
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return false }

        let words = cleaned.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty && !Self.fillerWords.contains($0) }

        return words.count >= 2
    }

    // MARK: - Date Extraction

    func extractActionableDate(from text: String) -> Date? {
        let detector: NSDataDetector
        do {
            detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        } catch {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        var foundDate: Date?
        var foundRange: NSRange?

        detector.enumerateMatches(in: text, options: [], range: range) { result, _, stop in
            guard let result = result, let date = result.date else { return }

            // Only consider future dates or dates within the last hour
            let now = Date()
            let oneHourAgo = now.addingTimeInterval(-3600)

            if date >= oneHourAgo {
                // Check if this result includes time information
                let hasTimeComponent = result.timeZone != nil ||
                    text.lowercased().contains("at ") ||
                    text.lowercased().contains("am") ||
                    text.lowercased().contains("pm") ||
                    text.lowercased().contains("o'clock")

                // Prefer dates with time components
                if foundDate == nil || hasTimeComponent {
                    foundDate = date
                    foundRange = result.range
                    if hasTimeComponent {
                        stop.pointee = true
                    }
                }
            }
        }

        // If we found "tomorrow" without a specific time, set it to 9 AM
        if let date = foundDate, let range = foundRange {
            let matchedText = (text as NSString).substring(with: range).lowercased()
            if matchedText.contains("tomorrow") || matchedText.contains("next") {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.hour, .minute], from: date)
                // If time is midnight (default), set to 9 AM
                if components.hour == 0 && components.minute == 0 {
                    var newComponents = calendar.dateComponents([.year, .month, .day], from: date)
                    newComponents.hour = 9
                    newComponents.minute = 0
                    return calendar.date(from: newComponents)
                }
            }
        }

        return foundDate
    }

    // MARK: - Digest Generation

    func generateDigestSummary(for notes: [VoiceNote]) -> String {
        guard !notes.isEmpty else {
            return "No notes recorded today."
        }

        var sections: [String] = []
        let notesByCategory = Dictionary(grouping: notes, by: { $0.category })

        for category in NoteCategory.allCases {
            if let categoryNotes = notesByCategory[category], !categoryNotes.isEmpty {
                let categorySection = buildCategorySummary(category: category, notes: categoryNotes)
                sections.append(categorySection)
            }
        }

        let allKeywords = notes.flatMap { $0.keywords }
        let keywordCounts = Dictionary(grouping: allKeywords, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        let topKeywords = Array(keywordCounts.prefix(5).map { $0.key })

        if !topKeywords.isEmpty {
            sections.append("🔑 \(topKeywords.joined(separator: ", "))")
        }

        let noteWord = notes.count == 1 ? "note" : "notes"
        sections.append("📊 \(notes.count) \(noteWord) recorded")

        return sections.joined(separator: "\n\n")
    }

    private func buildCategorySummary(category: NoteCategory, notes: [VoiceNote]) -> String {
        let header = "\(category.emoji) \(category.rawValue)"
        var lines: [String] = [header]

        let sortedNotes = notes.sorted { $0.createdAt < $1.createdAt }

        for note in sortedNotes {
            let abridged = abridgeContent(note.cleanedContent)
            lines.append("• \(abridged)")
        }

        return lines.joined(separator: "\n")
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
