import SwiftUI

struct RecordView: View {
    @Environment(VoiceNoteManager.self) private var manager

    @State private var isPressed = false
    @State private var blockOffsets: [CGSize] = Array(repeating: .zero, count: 9)
    @State private var blockScales: [CGFloat] = Array(repeating: 1.0, count: 9)
    @State private var idleAnimation = false

    private let accentColor = Color(red: 0.2, green: 0.2, blue: 0.25)
    private let recordingColor = Color(red: 0.95, green: 0.3, blue: 0.3)

    var body: some View {
        NavigationStack {
            ZStack {
                // Clean white background
                Color.white
                    .ignoresSafeArea()

                VStack(spacing: 48) {
                    Spacer()

                    // Status
                    statusView

                    // Duration when recording
                    if manager.isRecording {
                        durationView
                            .transition(.opacity.combined(with: .scale))
                    }

                    Spacer()

                    // AI Block Button
                    aiBlockButton
                        .frame(width: 200, height: 200)

                    Spacer()

                    // Instruction
                    instructionView

                    // Today's count
                    todayCountView
                        .padding(.bottom, 32)
                }
                .padding()
            }
            .navigationTitle("Record")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                startIdleAnimation()
                Task {
                    await manager.requestPermissions()
                }
            }
        }
    }

    // MARK: - Status View

    private var statusView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(manager.isRecording ? recordingColor : accentColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(manager.isRecording ? recordingColor : accentColor)
        }
        .animation(.easeInOut(duration: 0.3), value: manager.isRecording)
    }

    private var statusText: String {
        switch manager.recordingState {
        case .idle:
            return "Ready"
        case .recording:
            return "Listening"
        case .processing:
            return "Processing"
        case .error:
            return "Error"
        }
    }

    // MARK: - Duration View

    private var durationView: some View {
        Text(formatDuration(manager.recordingDuration))
            .font(.system(size: 48, weight: .light, design: .monospaced))
            .foregroundStyle(recordingColor)
    }

    // MARK: - AI Block Button

    private var aiBlockButton: some View {
        let columns = 3
        let rows = 3
        let blockSize: CGFloat = 44
        let spacing: CGFloat = 12

        return ZStack {
            // Subtle shadow/glow when recording
            if manager.isRecording {
                RoundedRectangle(cornerRadius: 24)
                    .fill(recordingColor.opacity(0.1))
                    .frame(width: 180, height: 180)
                    .blur(radius: 30)
            }

            // Grid of blocks
            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<columns, id: \.self) { col in
                            let index = row * columns + col
                            RoundedRectangle(cornerRadius: 10)
                                .fill(manager.isRecording ? recordingColor : accentColor)
                                .frame(width: blockSize, height: blockSize)
                                .scaleEffect(blockScales[index])
                                .offset(blockOffsets[index])
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed && !manager.isRecording && !manager.isProcessing {
                        isPressed = true
                        startRecording()
                    }
                }
                .onEnded { _ in
                    if isPressed && manager.isRecording {
                        isPressed = false
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
                        .scaleEffect(0.8)
                    Text("Analyzing")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            } else if !manager.hasMicrophonePermission || !manager.hasSpeechPermission {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    Text("Enable microphone & speech in Settings")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Hold to speak")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Today's Count

    private var todayCountView: some View {
        HStack(spacing: 4) {
            Text("\(manager.todaysNoteCount)")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(accentColor)
            Text("today")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Animations

    private func startIdleAnimation() {
        // Subtle breathing animation for idle state
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            idleAnimation = true
            for i in 0..<9 {
                blockScales[i] = 0.95
            }
        }
    }

    private func startRecording() {
        // Blocks move outward and pulse
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            let offsets: [CGSize] = [
                CGSize(width: -8, height: -8),  // top-left
                CGSize(width: 0, height: -10),  // top-center
                CGSize(width: 8, height: -8),   // top-right
                CGSize(width: -10, height: 0),  // middle-left
                CGSize(width: 0, height: 0),    // center
                CGSize(width: 10, height: 0),   // middle-right
                CGSize(width: -8, height: 8),   // bottom-left
                CGSize(width: 0, height: 10),   // bottom-center
                CGSize(width: 8, height: 8)     // bottom-right
            ]
            blockOffsets = offsets

            for i in 0..<9 {
                blockScales[i] = 1.1
            }
        }

        // Start pulsing animation
        startPulsingAnimation()

        manager.startRecording()
    }

    private func startPulsingAnimation() {
        guard manager.isRecording else { return }

        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            for i in 0..<9 {
                blockScales[i] = i == 4 ? 1.2 : 1.05 // Center block pulses more
            }
        }
    }

    private func stopRecording() {
        // Blocks return to original position
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            blockOffsets = Array(repeating: .zero, count: 9)
            for i in 0..<9 {
                blockScales[i] = 1.0
            }
        }

        manager.stopRecording()

        // Restart idle animation after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !manager.isRecording {
                startIdleAnimation()
            }
        }
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
