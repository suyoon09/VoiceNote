import SwiftUI

struct DigestView: View {
    @Environment(VoiceNoteManager.self) private var manager

    @State private var selectedDigest: DailyDigest?
    @State private var showingDigestDetail = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Today's section
                    todaySection

                    // Past digests section
                    pastDigestsSection
                }
                .padding()
            }
            .navigationTitle("Digest")
            .sheet(item: $selectedDigest) { digest in
                DigestDetailView(digest: digest)
            }
        }
    }

    // MARK: - Today's Section

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today")
                .font(.title2)
                .fontWeight(.bold)

            if manager.todaysNotes.isEmpty {
                // Empty state for today
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    Text("No notes recorded today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                // Today's notes by time of day
                VStack(spacing: 12) {
                    ForEach(TimeOfDay.allCases) { timeOfDay in
                        let notesForTime = manager.todaysNotes.filter { $0.timeOfDay == timeOfDay }
                        if !notesForTime.isEmpty {
                            TimeOfDaySectionCard(timeOfDay: timeOfDay, notes: notesForTime)
                        }
                    }

                    // Generate digest button
                    Button {
                        let digest = manager.generateDigest()
                        selectedDigest = digest
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Generate Today's Digest")
                            Spacer()
                            Text("\(manager.todaysNotes.count) notes")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    // MARK: - Past Digests Section

    private var pastDigestsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Past Digests")
                .font(.title2)
                .fontWeight(.bold)

            if manager.dailyDigests.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    Text("No digests yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Generate your first digest from today's notes")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(manager.dailyDigests) { digest in
                        DigestCard(digest: digest)
                            .onTapGesture {
                                selectedDigest = digest
                            }
                    }
                }
            }
        }
    }
}

// MARK: - Time of Day Section Card

struct TimeOfDaySectionCard: View {
    let timeOfDay: TimeOfDay
    let notes: [VoiceNote]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: timeOfDay.icon)
                    .foregroundStyle(iconColor)
                Text(timeOfDay.rawValue)
                    .fontWeight(.medium)
                Spacer()
                Text("\(notes.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
            .font(.subheadline)

            // Notes preview
            VStack(alignment: .leading, spacing: 4) {
                ForEach(notes.prefix(3)) { note in
                    HStack(spacing: 8) {
                        Text(note.category.emoji)
                            .font(.caption)
                        Text(note.cleanedContent)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                }

                if notes.count > 3 {
                    Text("+ \(notes.count - 3) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var iconColor: Color {
        switch timeOfDay {
        case .morning:
            return .orange
        case .afternoon:
            return .yellow
        case .evening:
            return .purple
        case .night:
            return .indigo
        }
    }
}

// MARK: - Digest Card

struct DigestCard: View {
    let digest: DailyDigest

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(digest.shortDate)
                        .font(.headline)

                    Text("\(digest.noteCount) notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Category breakdown
            HStack(spacing: 12) {
                ForEach(NoteCategory.allCases, id: \.self) { category in
                    if let count = digest.notesByCategory[category]?.count, count > 0 {
                        HStack(spacing: 4) {
                            Text(category.emoji)
                                .font(.caption2)
                            Text("\(count)")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }
                }
            }

            // Top keywords preview
            if !digest.topKeywords.isEmpty {
                HStack {
                    Image(systemName: "tag")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(digest.topKeywords.prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    DigestView()
        .environment(VoiceNoteManager())
}
