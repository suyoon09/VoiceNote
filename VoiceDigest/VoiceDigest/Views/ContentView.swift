import SwiftUI

struct ContentView: View {
    @Environment(VoiceNoteManager.self) private var manager

    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            // Global premium background
            AppColors.background
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                RecordView()
                    .tabItem {
                        Label("Record", systemImage: "mic.fill")
                    }
                    .tag(0)

                NotesListView()
                    .tabItem {
                        Label("Notes", systemImage: "list.bullet")
                    }
                    .tag(1)
                    .badge(manager.todaysNoteCount > 0 ? manager.todaysNoteCount : 0)

                DigestView()
                    .tabItem {
                        Label("Digest", systemImage: "doc.text.fill")
                    }
                    .tag(2)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(3)
            }
            .tint(AppColors.accent)

            // Toast overlay
            VStack {
                Spacer()

                if manager.showToast, let message = manager.toastMessage {
                    PremiumToastView(message: message)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 100)
                }
            }
            .animation(.spring(response: 0.3), value: manager.showToast)
        }
    }
}

// MARK: - Premium Toast View

struct PremiumToastView: View {
    let message: ToastMessage

    var body: some View {
        HStack(spacing: 12) {
            // Icon with accent circle background
            ZStack {
                Circle()
                    .fill(message.isError ? Color.red.opacity(0.15) : AppColors.accentSecondary.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: message.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(message.isError ? .red : AppColors.accentSecondary)
            }

            Text(message.message)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.primaryText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardBackground)
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 4)
        )
    }
}

// Keep the old ToastView for backward compatibility if needed elsewhere
struct ToastView: View {
    let message: ToastMessage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: message.icon)
                .font(.headline)
                .foregroundStyle(message.isError ? .red : .green)

            Text(message.message)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    ContentView()
        .environment(VoiceNoteManager())
}
