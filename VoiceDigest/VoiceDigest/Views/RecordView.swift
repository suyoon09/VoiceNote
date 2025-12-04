import SwiftUI

struct RecordView: View {
    @Environment(VoiceNoteManager.self) private var manager

    @State private var pulseAnimation = false
    @State private var buttonScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                // Status text
                statusView

                // Recording duration
                if manager.isRecording {
                    durationView
                }

                // Main record button
                recordButton

                // Instructions or processing indicator
                instructionView

                Spacer()

                // Today's note count
                todayCountView
            }
            .padding()
            .navigationTitle("Record")
            .onAppear {
                Task {
                    await manager.requestPermissions()
                }
            }
        }
    }

    // MARK: - Status View

    private var statusView: some View {
        Group {
            switch manager.recordingState {
            case .idle:
                Text("Hold to Record")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            case .recording:
                Text("Recording...")
                    .font(.title2)
                    .foregroundStyle(.red)
            case .processing:
                Text("Processing...")
                    .font(.title2)
                    .foregroundStyle(.blue)
            case .error(let message):
                Text(message)
                    .font(.title2)
                    .foregroundStyle(.red)
            }
        }
        .animation(.easeInOut, value: manager.recordingState)
    }

    // MARK: - Duration View

    private var durationView: some View {
        Text(formatDuration(manager.recordingDuration))
            .font(.system(size: 48, weight: .light, design: .monospaced))
            .foregroundStyle(.primary)
            .transition(.opacity)
    }

    // MARK: - Record Button

    private var recordButton: some View {
        ZStack {
            // Outer pulse ring (when recording)
            if manager.isRecording {
                Circle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 4)
                    .frame(width: 200, height: 200)
                    .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                    .opacity(pulseAnimation ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                        value: pulseAnimation
                    )
            }

            // Main button
            Circle()
                .fill(manager.isRecording ? Color.red : Color.blue)
                .frame(width: 160, height: 160)
                .shadow(color: (manager.isRecording ? Color.red : Color.blue).opacity(0.4), radius: 20)
                .scaleEffect(buttonScale)
                .overlay {
                    if manager.isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(2)
                    } else {
                        Image(systemName: manager.isRecording ? "waveform" : "mic.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.white)
                            .symbolEffect(.variableColor.iterative, isActive: manager.isRecording)
                    }
                }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !manager.isRecording && !manager.isProcessing {
                        startRecording()
                    }
                }
                .onEnded { _ in
                    if manager.isRecording {
                        stopRecording()
                    }
                }
        )
        .disabled(manager.isProcessing)
        .sensoryFeedback(.impact(flexibility: .solid), trigger: manager.isRecording)
    }

    // MARK: - Instruction View

    private var instructionView: some View {
        Group {
            if manager.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Transcribing your note...")
                        .foregroundStyle(.secondary)
                }
            } else if !manager.hasMicrophonePermission || !manager.hasSpeechPermission {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundStyle(.orange)
                    Text("Please enable microphone and speech recognition in Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                Text("Press and hold the button, then speak your thought")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Today's Count

    private var todayCountView: some View {
        VStack(spacing: 4) {
            Text("\(manager.todaysNoteCount)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("notes today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Actions

    private func startRecording() {
        withAnimation(.spring(response: 0.3)) {
            buttonScale = 0.95
        }
        pulseAnimation = true
        manager.startRecording()
    }

    private func stopRecording() {
        withAnimation(.spring(response: 0.3)) {
            buttonScale = 1.0
        }
        pulseAnimation = false
        manager.stopRecording()
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

// MARK: - Recording State Extension

extension RecordingState: Equatable {
    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.recording, .recording), (.processing, .processing):
            return true
        case (.error(let lhsMsg), .error(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

#Preview {
    RecordView()
        .environment(VoiceNoteManager())
}
