import SwiftUI

struct NotesListView: View {
    @Environment(VoiceNoteManager.self) private var manager

    var body: some View {
        NavigationStack {
            Group {
                if manager.voiceNotes.isEmpty {
                    emptyStateView
                } else {
                    notesList
                }
            }
            .navigationTitle("Notes")
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Notes Yet", systemImage: "mic.badge.plus")
        } description: {
            Text("Record your first voice note by pressing and holding the record button.")
        } actions: {
            Button("Go to Record") {
                // This would need to switch tabs - handled at parent level
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Notes List

    private var notesList: some View {
        List {
            // Notes by date
            ForEach(groupedNotes, id: \.key) { group in
                Section {
                    ForEach(group.value) { note in
                        NoteCardView(note: note) {
                            withAnimation {
                                manager.deleteNote(note)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    manager.deleteNote(note)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(group.key)
                        .font(.headline)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Grouped Notes

    private var groupedNotes: [(key: String, value: [VoiceNote])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: manager.voiceNotes) { note -> String in
            if calendar.isDateInToday(note.createdAt) {
                return "Today"
            } else if calendar.isDateInYesterday(note.createdAt) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: note.createdAt)
            }
        }

        // Sort groups with Today first, then Yesterday, then by date descending
        return grouped.sorted { lhs, rhs in
            if lhs.key == "Today" { return true }
            if rhs.key == "Today" { return false }
            if lhs.key == "Yesterday" { return true }
            if rhs.key == "Yesterday" { return false }
            return lhs.key > rhs.key
        }
    }
}

// MARK: - Note Card View

struct NoteCardView: View {
    @Environment(VoiceNoteManager.self) private var manager
    let note: VoiceNote
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category and time row
            HStack {
                // Category badge
                HStack(spacing: 4) {
                    Text(note.category.emoji)
                    Text(note.category.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(categoryColor.opacity(0.15))
                .foregroundStyle(categoryColor)
                .clipShape(Capsule())

                // Calendar indicator for notes with actionable dates
                if note.hasActionableDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.caption)
                        if let formattedDate = note.formattedActionableDate {
                            Text(formattedDate)
                                .font(.caption2)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.15))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
                }

                Spacer()

                // Time
                Text(note.formattedTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Content
            Text(note.cleanedContent)
                .font(.body)
                .lineLimit(3)

            // Keywords
            if !note.keywords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(note.keywords.prefix(5), id: \.self) { keyword in
                            Text(keyword)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray5))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            // Share option
            ShareLink(item: note.cleanedContent) {
                Label("Share Text", systemImage: "square.and.arrow.up")
            }

            Divider()

            // Add to Calendar option
            Button {
                manager.addToCalendar(note: note)
            } label: {
                if note.hasActionableDate {
                    Label("Add to Calendar (\(note.formattedActionableDate ?? ""))", systemImage: "calendar.badge.plus")
                } else {
                    Label("Add to Calendar", systemImage: "calendar.badge.plus")
                }
            }

            Divider()

            // Delete option
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var categoryColor: Color {
        switch note.category {
        case .work:
            return .blue
        case .personal:
            return .green
        case .ideas:
            return .yellow
        case .tasks:
            return .orange
        case .uncategorized:
            return .gray
        }
    }
}

// MARK: - Digest Detail View

struct DigestDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let digest: DailyDigest
    var onShare: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(digest.formattedDate)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("\(digest.noteCount) notes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Summary
                    if !digest.summary.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Summary", systemImage: "text.alignleft")
                                .font(.headline)

                            Text(digest.summary)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    // Top keywords
                    if !digest.topKeywords.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Top Keywords", systemImage: "key.fill")
                                .font(.headline)

                            FlowLayout(spacing: 8) {
                                ForEach(digest.topKeywords, id: \.self) { keyword in
                                    Text(keyword)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundStyle(.blue)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    Divider()
                        .padding(.horizontal)

                    // Notes by category
                    ForEach(NoteCategory.allCases, id: \.self) { category in
                        if let notes = digest.notesByCategory[category], !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(category.emoji)
                                    Text(category.rawValue)
                                        .fontWeight(.semibold)
                                    Text("(\(notes.count))")
                                        .foregroundStyle(.secondary)
                                }
                                .font(.headline)

                                ForEach(notes) { note in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text(note.formattedTime)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 60, alignment: .leading)

                                        Text(note.cleanedContent)
                                            .font(.body)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding(.horizontal)

                            if category != NoteCategory.allCases.last {
                                Divider()
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Daily Digest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let onShare = onShare {
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onShare()
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > width && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                self.size.width = max(self.size.width, currentX)
            }

            self.size.height = currentY + lineHeight
        }
    }
}

#Preview {
    NotesListView()
        .environment(VoiceNoteManager())
}
