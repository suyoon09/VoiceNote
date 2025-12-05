import SwiftUI

struct NotesListView: View {
    @Environment(VoiceNoteManager.self) private var manager
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            ZStack {
                // Premium background
                AppColors.background
                    .ignoresSafeArea()

                Group {
                    if manager.voiceNotes.isEmpty {
                        emptyStateView
                    } else {
                        notesScrollView
                    }
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppColors.background, for: .navigationBar)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "mic.badge.plus")
                    .font(.system(size: 40))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(spacing: 8) {
                Text("No Notes Yet")
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.primaryText)

                Text("Record your first voice note by\npressing and holding the record button.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Notes Scroll View

    private var notesScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 24, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedNotes, id: \.key) { group in
                    Section {
                        VStack(spacing: 12) {
                            ForEach(group.value) { note in
                                PremiumNoteCard(note: note) {
                                    withAnimation(.spring(response: 0.3)) {
                                        manager.deleteNote(note)
                                    }
                                }
                            }
                        }
                    } header: {
                        sectionHeader(title: group.key, count: group.value.count)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.primaryText)

            Text("\(count)")
                .font(AppTypography.captionSmall)
                .foregroundStyle(AppColors.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppColors.accent.opacity(0.1))
                .clipShape(Capsule())

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(AppColors.background)
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

        return grouped.sorted { lhs, rhs in
            if lhs.key == "Today" { return true }
            if rhs.key == "Today" { return false }
            if lhs.key == "Yesterday" { return true }
            if rhs.key == "Yesterday" { return false }
            return lhs.key > rhs.key
        }
    }
}

// MARK: - Premium Note Card

struct PremiumNoteCard: View {
    @Environment(VoiceNoteManager.self) private var manager
    let note: VoiceNote
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: Time pill and calendar indicator
            HStack(spacing: 8) {
                // Time pill (Electric Indigo)
                Text(note.formattedTime)
                    .accentPill(color: AppColors.accent)

                // Calendar indicator
                if note.hasActionableDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 10))
                        if let formattedDate = note.formattedActionableDate {
                            Text(formattedDate)
                                .font(AppTypography.captionSmall)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(AppColors.accentSecondary.opacity(0.1))
                    .foregroundStyle(AppColors.accentSecondary)
                    .clipShape(Capsule())
                }

                Spacer()

                // Subtle category tag
                Text(note.category.rawValue)
                    .subtleTag(color: note.category.sophisticatedColor)
            }

            // Content
            Text(note.cleanedContent)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.primaryText)
                .lineLimit(3)
                .lineSpacing(2)

            // Keywords (horizontal scroll pills)
            if !note.keywords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(note.keywords.prefix(5), id: \.self) { keyword in
                            Text(keyword)
                                .font(AppTypography.captionSmall)
                                .foregroundStyle(AppColors.tertiaryText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppColors.divider)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .sophisticatedCard()
        .contentShape(Rectangle())
        .contextMenu {
            // Share option
            ShareLink(item: note.cleanedContent) {
                Label("Share Text", systemImage: "square.and.arrow.up")
            }

            Divider()

            // Add to Calendar
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

            // Delete
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
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
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text(digest.formattedDate)
                                .font(AppTypography.displaySerif)
                                .foregroundStyle(AppColors.primaryText)

                            Text("\(digest.noteCount) notes recorded")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Summary in quote block style
                        if !digest.summary.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Summary", systemImage: "text.alignleft")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.secondaryText)

                                Text(digest.summary)
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColors.primaryText)
                                    .quoteBlock()
                            }
                            .padding()
                            .sophisticatedCard(padding: 0, cornerRadius: 16)
                            .padding(.horizontal)
                        }

                        // Top keywords as horizontal pills
                        if !digest.topKeywords.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Top Keywords")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.secondaryText)
                                    .padding(.horizontal)

                                KeywordPillsView(keywords: digest.topKeywords)
                                    .padding(.horizontal)
                            }
                        }

                        // Notes by category
                        ForEach(NoteCategory.allCases, id: \.self) { category in
                            if let notes = digest.notesByCategory[category], !notes.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text(category.emoji)
                                        Text(category.rawValue)
                                            .font(AppTypography.cardTitle)
                                            .foregroundStyle(AppColors.primaryText)
                                        Text("(\(notes.count))")
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.tertiaryText)
                                    }

                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(notes) { note in
                                            HStack(alignment: .top, spacing: 12) {
                                                ActionCheckmark(color: category.sophisticatedColor)

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(note.cleanedContent)
                                                        .font(AppTypography.body)
                                                        .foregroundStyle(AppColors.primaryText)

                                                    Text(note.formattedTime)
                                                        .font(AppTypography.captionSmall)
                                                        .foregroundStyle(AppColors.tertiaryText)
                                                }
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                }
                                .padding()
                                .sophisticatedCard(padding: 0, cornerRadius: 16)
                                .padding(.horizontal)
                            }
                        }

                        // Watermark footer
                        WatermarkFooter()
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Daily Digest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
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
                                .foregroundStyle(AppColors.accent)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(AppColors.accent)
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
