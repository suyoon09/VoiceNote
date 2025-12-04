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
            // Match filler words with word boundaries
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

        // Trim whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Capitalize first letter
        if !cleaned.isEmpty {
            cleaned = cleaned.prefix(1).uppercased() + cleaned.dropFirst()
        }

        // Ensure proper ending punctuation
        if !cleaned.isEmpty && !cleaned.hasSuffix(".") && !cleaned.hasSuffix("!") && !cleaned.hasSuffix("?") {
            cleaned += "."
        }

        // Fix common patterns
        cleaned = fixCapitalization(cleaned)
        cleaned = fixPunctuation(cleaned)

        return cleaned
    }

    private func fixCapitalization(_ text: String) -> String {
        var result = text

        // Capitalize "I"
        result = result.replacingOccurrences(of: " i ", with: " I ")
        result = result.replacingOccurrences(of: " i'", with: " I'")

        // Capitalize after periods
        let sentences = result.components(separatedBy: ". ")
        result = sentences.map { sentence in
            guard !sentence.isEmpty else { return sentence }
            return sentence.prefix(1).uppercased() + sentence.dropFirst()
        }.joined(separator: ". ")

        return result
    }

    private func fixPunctuation(_ text: String) -> String {
        var result = text

        // Fix comma-separated lists
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

        // Fix double punctuation
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
                    // Multi-word keywords get higher score
                    score += keyword.contains(" ") ? 3 : 1
                }
            }
            categoryScores[category] = score
        }

        // Return category with highest score, or uncategorized if no matches
        if let (category, score) = categoryScores.max(by: { $0.value < $1.value }), score > 0 {
            return category
        }

        return .uncategorized
    }

    // MARK: - Keyword Extraction

    func extractKeywords(from text: String, maxKeywords: Int = 10) -> [String] {
        var keywords: Set<String> = []

        // Use NLTagger for lexical analysis
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]

        // Extract nouns and proper nouns
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            if let tag = tag {
                let word = String(text[tokenRange]).lowercased()

                // Only include words with 4+ characters
                guard word.count >= 4 else { return true }

                // Skip common words and filler words
                guard !isCommonWord(word) && !Self.fillerWords.contains(word) else { return true }

                // Include nouns and verbs
                if tag == .noun || tag == .verb || tag == .adjective {
                    keywords.insert(word.capitalized)
                }
            }
            return true
        }

        // Extract named entities (people, places, organizations)
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if let tag = tag {
                let word = String(text[tokenRange])
                if tag == .personalName || tag == .placeName || tag == .organizationName {
                    keywords.insert(word)
                }
            }
            return true
        }

        // Sort by length (longer keywords tend to be more specific) and limit
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

        // Check if empty
        guard !cleaned.isEmpty else { return false }

        // Check minimum word count
        let words = cleaned.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty && !Self.fillerWords.contains($0) }

        // Require at least 2 meaningful words
        return words.count >= 2
    }

    // MARK: - Digest Generation

    func generateDigestSummary(for notes: [VoiceNote]) -> String {
        guard !notes.isEmpty else {
            return "No notes recorded today."
        }

        var sections: [String] = []

        // Group by category
        let notesByCategory = Dictionary(grouping: notes, by: { $0.category })

        // Build fluid summary for each category
        for category in NoteCategory.allCases {
            if let categoryNotes = notesByCategory[category], !categoryNotes.isEmpty {
                let categorySection = buildCategorySummary(category: category, notes: categoryNotes)
                sections.append(categorySection)
            }
        }

        // Add top keywords
        let allKeywords = notes.flatMap { $0.keywords }
        let keywordCounts = Dictionary(grouping: allKeywords, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        let topKeywords = Array(keywordCounts.prefix(5).map { $0.key })

        if !topKeywords.isEmpty {
            sections.append("🔑 Key themes: \(topKeywords.joined(separator: ", "))")
        }

        // Add statistics
        let noteWord = notes.count == 1 ? "note" : "notes"
        sections.append("📊 You recorded \(notes.count) \(noteWord) today")

        return sections.joined(separator: "\n\n")
    }

    private func buildCategorySummary(category: NoteCategory, notes: [VoiceNote]) -> String {
        let header = "\(category.emoji) \(category.rawValue)"

        if notes.count == 1 {
            let note = notes[0]
            let timeStr = formatTime(note.createdAt)
            return "\(header)\nAt \(timeStr), you noted: \(note.cleanedContent)"
        }

        // Multiple notes - create a fluid summary
        var lines: [String] = [header]

        // Group by time periods for natural flow
        let sortedNotes = notes.sorted { $0.createdAt < $1.createdAt }

        for (index, note) in sortedNotes.enumerated() {
            let timeStr = formatTime(note.createdAt)
            let connector = getConnector(for: index, total: sortedNotes.count)
            lines.append("\(connector)\(timeStr): \(note.cleanedContent)")
        }

        return lines.joined(separator: "\n")
    }

    private func getConnector(for index: Int, total: Int) -> String {
        if index == 0 {
            return "• "
        } else if index == total - 1 {
            return "• "
        } else {
            return "• "
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
