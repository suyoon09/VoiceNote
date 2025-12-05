import SwiftUI
import UIKit

struct DigestView: View {
    @Environment(VoiceNoteManager.self) private var manager

    @State private var selectedDigest: DailyDigest?
    @State private var pdfToShare: Data?
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Premium background
                AppColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Today's Newsletter Card
                        todayNewsletterCard

                        // Past Digests Section
                        pastDigestsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Digest")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .sheet(item: $selectedDigest) { digest in
                DigestDetailView(digest: digest, onShare: {
                    shareDigest(digest)
                })
            }
            .sheet(isPresented: $showingShareSheet) {
                if let pdfData = pdfToShare {
                    ShareSheet(items: [pdfData])
                }
            }
        }
    }

    // MARK: - Share Functionality

    private func shareDigest(_ digest: DailyDigest) {
        pdfToShare = PDFGenerator.generateDigestPDF(from: digest)
        showingShareSheet = true
    }

    // MARK: - Today's Newsletter Card

    private var todayNewsletterCard: some View {
        VStack(spacing: 0) {
            // Paper card container
            VStack(alignment: .leading, spacing: 20) {
                // Newspaper-style header
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedTodayDate)
                        .font(AppTypography.displaySerif)
                        .foregroundStyle(AppColors.primaryText)

                    Rectangle()
                        .fill(AppColors.primaryText)
                        .frame(height: 2)

                    Text("YOUR DAILY BRIEFING")
                        .font(AppTypography.captionSmall)
                        .tracking(2)
                        .foregroundStyle(AppColors.tertiaryText)
                        .padding(.top, 4)
                }

                if manager.todaysNotes.isEmpty {
                    // Empty state
                    emptyTodayState
                } else {
                    // Today's content
                    todayContent
                }
            }
            .padding(24)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
        }
    }

    private var formattedTodayDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    // MARK: - Empty Today State

    private var emptyTodayState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.08))
                    .frame(width: 80, height: 80)

                Image(systemName: "doc.text")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(spacing: 4) {
                Text("No notes recorded today")
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.primaryText)

                Text("Start recording to build your daily digest")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Today Content

    private var todayContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Time of day sections
            ForEach(TimeOfDay.allCases) { timeOfDay in
                let notesForTime = manager.todaysNotes.filter { $0.timeOfDay == timeOfDay }
                if !notesForTime.isEmpty {
                    PremiumTimeSection(timeOfDay: timeOfDay, notes: notesForTime)
                }
            }

            // Divider
            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 1)

            // Generate Digest Button
            Button {
                let digest = manager.generateDigest()
                selectedDigest = digest
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .medium))

                    Text("Generate Today's Digest")
                        .font(AppTypography.cardTitle)

                    Spacer()

                    HStack(spacing: 4) {
                        Text("\(manager.todaysNotes.count)")
                            .font(AppTypography.caption)
                        Text("notes")
                            .font(AppTypography.captionSmall)
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [AppColors.accent, AppColors.accent.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            // Watermark
            WatermarkFooter(text: "VoiceDigest Daily")
        }
    }

    // MARK: - Past Digests Section

    private var pastDigestsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text("Past Digests")
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.primaryText)

                Spacer()

                if !manager.dailyDigests.isEmpty {
                    Text("\(manager.dailyDigests.count)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppColors.accent.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            if manager.dailyDigests.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(AppColors.tertiaryText)

                    VStack(spacing: 4) {
                        Text("No digests yet")
                            .font(AppTypography.cardTitle)
                            .foregroundStyle(AppColors.secondaryText)

                        Text("Generate your first digest from today's notes")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.tertiaryText)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .sophisticatedCard()
            } else {
                // Past digest cards
                LazyVStack(spacing: 12) {
                    ForEach(manager.dailyDigests) { digest in
                        PremiumDigestCard(digest: digest) {
                            shareDigest(digest)
                        }
                        .onTapGesture {
                            selectedDigest = digest
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Premium Time Section

struct PremiumTimeSection: View {
    let timeOfDay: TimeOfDay
    let notes: [VoiceNote]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with icon
            HStack(spacing: 8) {
                Image(systemName: timeOfDay.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(timeOfDay.sophisticatedColor)

                Text(timeOfDay.rawValue)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.primaryText)

                Text("\(notes.count)")
                    .font(AppTypography.captionSmall)
                    .foregroundStyle(timeOfDay.sophisticatedColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(timeOfDay.sophisticatedColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            // Notes list with checkmarks
            VStack(alignment: .leading, spacing: 6) {
                ForEach(notes.prefix(4)) { note in
                    HStack(alignment: .top, spacing: 10) {
                        ActionCheckmark(color: timeOfDay.sophisticatedColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(note.cleanedContent)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.primaryText)
                                .lineLimit(2)

                            HStack(spacing: 6) {
                                Text(note.formattedTime)
                                    .font(AppTypography.captionSmall)
                                    .foregroundStyle(AppColors.tertiaryText)

                                Text(note.category.rawValue)
                                    .subtleTag(color: note.category.sophisticatedColor)
                            }
                        }
                    }
                }

                if notes.count > 4 {
                    Text("+ \(notes.count - 4) more")
                        .font(AppTypography.captionSmall)
                        .foregroundStyle(AppColors.tertiaryText)
                        .padding(.leading, 32)
                }
            }
        }
        .padding(14)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Premium Digest Card

struct PremiumDigestCard: View {
    let digest: DailyDigest
    var onShare: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(digest.shortDate)
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColors.primaryText)

                    Text("\(digest.noteCount) notes")
                        .font(AppTypography.captionSmall)
                        .foregroundStyle(AppColors.secondaryText)
                }

                Spacer()

                HStack(spacing: 12) {
                    // Share button
                    if let onShare = onShare {
                        Button {
                            onShare()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14))
                                .foregroundStyle(AppColors.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.tertiaryText)
                }
            }

            // Category breakdown with pills
            HStack(spacing: 8) {
                ForEach(NoteCategory.allCases, id: \.self) { category in
                    if let count = digest.notesByCategory[category]?.count, count > 0 {
                        HStack(spacing: 4) {
                            Text(category.emoji)
                                .font(.system(size: 11))
                            Text("\(count)")
                                .font(AppTypography.captionSmall)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(category.sophisticatedColor.opacity(0.1))
                        .foregroundStyle(category.sophisticatedColor)
                        .clipShape(Capsule())
                    }
                }
            }

            // Keywords as horizontal scroll
            if !digest.topKeywords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Image(systemName: "tag")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.tertiaryText)

                        ForEach(digest.topKeywords.prefix(4), id: \.self) { keyword in
                            Text(keyword)
                                .font(AppTypography.captionSmall)
                                .foregroundStyle(AppColors.secondaryText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppColors.divider)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .sophisticatedCard()
        .contentShape(Rectangle())
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    DigestView()
        .environment(VoiceNoteManager())
}
