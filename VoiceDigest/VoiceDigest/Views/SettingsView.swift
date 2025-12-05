import SwiftUI
import Speech

struct SettingsView: View {
    @Environment(VoiceNoteManager.self) private var manager
    @AppStorage("autoSyncCalendar") private var autoSyncCalendar = false

    var body: some View {
        NavigationStack {
            List {
                // Notifications section
                notificationsSection

                // Calendar section
                calendarSection

                // Permissions section
                permissionsSection

                // Statistics section
                statisticsSection

                // About section
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Notifications Section

    @ViewBuilder
    private var notificationsSection: some View {
        @Bindable var managerBindable = manager

        Section {
            DatePicker(
                "Daily Digest Time",
                selection: $managerBindable.digestNotificationTime,
                displayedComponents: .hourAndMinute
            )
        } header: {
            Text("Notifications")
        } footer: {
            Text("You'll receive a notification at this time to review your daily digest.")
        }
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        Section {
            Toggle(isOn: $autoSyncCalendar) {
                Label("Auto-Sync Dates to Calendar", systemImage: "calendar.badge.plus")
            }
            .onChange(of: autoSyncCalendar) { _, newValue in
                if newValue && !manager.hasCalendarPermission {
                    Task {
                        await manager.requestCalendarPermission()
                        if !manager.hasCalendarPermission {
                            autoSyncCalendar = false
                        }
                    }
                }
            }

            // Calendar permission status
            HStack {
                Label("Calendar Access", systemImage: "calendar")

                Spacer()

                if manager.hasCalendarPermission {
                    Label("Authorized", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Button("Enable") {
                        Task {
                            await manager.requestCalendarPermission()
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }
        } header: {
            Text("Calendar")
        } footer: {
            Text("When enabled, voice notes with detected dates will automatically be added to your calendar.")
        }
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        Section("Permissions") {
            // Microphone permission
            HStack {
                Label("Microphone", systemImage: "mic.fill")

                Spacer()

                if manager.hasMicrophonePermission {
                    Label("Authorized", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Button("Enable") {
                        openSettings()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }

            // Speech recognition permission
            HStack {
                Label("Speech Recognition", systemImage: "waveform")

                Spacer()

                if manager.hasSpeechPermission {
                    Label("Authorized", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Button("Enable") {
                        openSettings()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }

            // On-device recognition status
            HStack {
                Label("On-Device Recognition", systemImage: "iphone")

                Spacer()

                if manager.speechRecognizer.isOnDeviceRecognitionAvailable {
                    Label("Available", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text("Not Available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        Section("Statistics") {
            StatRow(
                icon: "mic.fill",
                title: "Total Notes",
                value: "\(manager.statistics.totalNotes)"
            )

            StatRow(
                icon: "doc.text.fill",
                title: "Total Digests",
                value: "\(manager.statistics.totalDigests)"
            )

            StatRow(
                icon: "clock.fill",
                title: "Recording Time",
                value: manager.statistics.formattedRecordingTime
            )

            // Category breakdown
            if !manager.statistics.categoryCounts.isEmpty {
                DisclosureGroup {
                    ForEach(NoteCategory.allCases, id: \.self) { category in
                        if let count = manager.statistics.categoryCounts[category.rawValue], count > 0 {
                            HStack {
                                Text(category.emoji)
                                Text(category.rawValue)
                                Spacer()
                                Text("\(count)")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }
                    }
                } label: {
                    Label("By Category", systemImage: "chart.pie.fill")
                }
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("Build", systemImage: "hammer")
                Spacer()
                Text("1")
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://apple.com/privacy")!) {
                Label("Privacy Policy", systemImage: "hand.raised.fill")
            }
        }
    }

    // MARK: - Helpers

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    SettingsView()
        .environment(VoiceNoteManager())
}
