import SwiftUI

struct RecordView: View {
    @Environment(VoiceNoteManager.self) private var manager

    @State private var pulseAnimation = false
    @State private var buttonScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    @State private var innerRingRotation: Double = 0
    @State private var glowIntensity: Double = 0.5
    @State private var particleOffset: CGFloat = 0

    private let primaryGlow = Color(red: 0.0, green: 0.8, blue: 1.0)
    private let secondaryGlow = Color(red: 0.6, green: 0.2, blue: 1.0)
    private let recordingGlow = Color(red: 1.0, green: 0.2, blue: 0.4)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Futuristic gradient background
                backgroundGradient

                // Floating particles
                floatingParticles(in: geometry.size)

                // Main content
                VStack(spacing: 32) {
                    Spacer()

                    // AI Status indicator
                    aiStatusView

                    // Recording duration
                    if manager.isRecording {
                        durationView
                    }

                    Spacer()

                    // Main record button with rings
                    ZStack {
                        // Outer rotating rings
                        outerRingsView

                        // Core button
                        recordButton
                    }
                    .frame(width: 280, height: 280)

                    Spacer()

                    // Instructions
                    instructionView

                    // Today's note count
                    todayCountView
                        .padding(.bottom, 20)
                }
                .padding()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startAnimations()
            Task {
                await manager.requestPermissions()
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            // Base dark gradient
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.08),
                    Color(red: 0.05, green: 0.03, blue: 0.15),
                    Color(red: 0.02, green: 0.02, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Radial glow from center
            RadialGradient(
                colors: [
                    (manager.isRecording ? recordingGlow : primaryGlow).opacity(0.15),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .blur(radius: 60)

            // Ambient glow spots
            Circle()
                .fill(secondaryGlow.opacity(0.1))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: -150, y: -300)

            Circle()
                .fill(primaryGlow.opacity(0.08))
                .frame(width: 250, height: 250)
                .blur(radius: 80)
                .offset(x: 150, y: 400)
        }
    }

    // MARK: - Floating Particles

    private func floatingParticles(in size: CGSize) -> some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                Circle()
                    .fill(
                        (index % 2 == 0 ? primaryGlow : secondaryGlow)
                            .opacity(Double.random(in: 0.1...0.3))
                    )
                    .frame(width: CGFloat.random(in: 2...6), height: CGFloat.random(in: 2...6))
                    .offset(
                        x: CGFloat.random(in: -size.width/2...size.width/2),
                        y: sin(particleOffset + Double(index) * 0.5) * 20 + CGFloat.random(in: -size.height/3...size.height/3)
                    )
                    .blur(radius: 1)
            }
        }
    }

    // MARK: - AI Status View

    private var aiStatusView: some View {
        HStack(spacing: 12) {
            // Pulsing AI indicator
            Circle()
                .fill(manager.isRecording ? recordingGlow : primaryGlow)
                .frame(width: 8, height: 8)
                .shadow(color: manager.isRecording ? recordingGlow : primaryGlow, radius: 8)
                .scaleEffect(glowIntensity)

            Text(statusText)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: manager.isRecording ? [recordingGlow, .white] : [primaryGlow, .white],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: (manager.isRecording ? recordingGlow : primaryGlow).opacity(0.5), radius: 10)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.05))
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    (manager.isRecording ? recordingGlow : primaryGlow).opacity(0.5),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    private var statusText: String {
        switch manager.recordingState {
        case .idle:
            return "AI Ready"
        case .recording:
            return "Listening..."
        case .processing:
            return "Processing..."
        case .error:
            return "Error"
        }
    }

    // MARK: - Duration View

    private var durationView: some View {
        Text(formatDuration(manager.recordingDuration))
            .font(.system(size: 56, weight: .ultraLight, design: .monospaced))
            .foregroundStyle(
                LinearGradient(
                    colors: [recordingGlow, .white],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: recordingGlow.opacity(0.5), radius: 20)
            .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Outer Rings

    private var outerRingsView: some View {
        ZStack {
            // Outermost ring - slow rotation
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            primaryGlow.opacity(0.3),
                            secondaryGlow.opacity(0.1),
                            primaryGlow.opacity(0.3),
                            Color.clear,
                            primaryGlow.opacity(0.3)
                        ],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .frame(width: 260, height: 260)
                .rotationEffect(.degrees(rotationAngle))

            // Middle ring - dashed
            Circle()
                .stroke(
                    (manager.isRecording ? recordingGlow : primaryGlow).opacity(0.4),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 8])
                )
                .frame(width: 230, height: 230)
                .rotationEffect(.degrees(-rotationAngle * 0.7))

            // Inner ring - faster rotation
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            (manager.isRecording ? recordingGlow : secondaryGlow).opacity(0.5),
                            Color.clear,
                            (manager.isRecording ? recordingGlow : secondaryGlow).opacity(0.5)
                        ],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(innerRingRotation))

            // Pulse rings when recording
            if manager.isRecording {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(recordingGlow.opacity(0.3), lineWidth: 2)
                        .frame(width: 180, height: 180)
                        .scaleEffect(pulseAnimation ? 1.5 + CGFloat(index) * 0.2 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.6)
                        .animation(
                            .easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.3),
                            value: pulseAnimation
                        )
                }
            }
        }
    }

    // MARK: - Record Button

    private var recordButton: some View {
        ZStack {
            // Glow base
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            (manager.isRecording ? recordingGlow : primaryGlow).opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 60,
                        endRadius: 100
                    )
                )
                .frame(width: 180, height: 180)
                .blur(radius: 20)

            // Main button
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            manager.isRecording ? recordingGlow.opacity(0.9) : primaryGlow.opacity(0.8),
                            manager.isRecording ? recordingGlow.opacity(0.6) : secondaryGlow.opacity(0.6),
                            Color(red: 0.1, green: 0.1, blue: 0.2)
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 140, height: 140)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.6),
                                    (manager.isRecording ? recordingGlow : primaryGlow).opacity(0.3),
                                    .white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: (manager.isRecording ? recordingGlow : primaryGlow).opacity(0.6),
                    radius: 30
                )
                .scaleEffect(buttonScale)
                .overlay {
                    if manager.isProcessing {
                        // Processing spinner
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 3)
                                .frame(width: 60, height: 60)

                            Circle()
                                .trim(from: 0, to: 0.3)
                                .stroke(
                                    LinearGradient(colors: [primaryGlow, .white], startPoint: .leading, endPoint: .trailing),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .frame(width: 60, height: 60)
                                .rotationEffect(.degrees(rotationAngle * 3))
                        }
                    } else {
                        // Icon
                        Image(systemName: manager.isRecording ? "waveform" : "mic.fill")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.5), radius: 10)
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
                HStack(spacing: 12) {
                    Text("Analyzing voice patterns")
                        .foregroundStyle(primaryGlow)
                }
                .font(.system(size: 14, weight: .medium))
            } else if !manager.hasMicrophonePermission || !manager.hasSpeechPermission {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text("Enable microphone and speech recognition")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Press and hold to record")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Today's Count

    private var todayCountView: some View {
        HStack(spacing: 16) {
            // Count display
            VStack(spacing: 2) {
                Text("\(manager.todaysNoteCount)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [primaryGlow, .white],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Text("notes today")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [primaryGlow.opacity(0.3), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Actions

    private func startRecording() {
        withAnimation(.spring(response: 0.3)) {
            buttonScale = 0.92
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

    private func startAnimations() {
        // Continuous ring rotation
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }

        // Inner ring rotation (opposite direction)
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
            innerRingRotation = -360
        }

        // Glow pulsing
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            glowIntensity = 1.2
        }

        // Particle floating
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            particleOffset = .pi * 2
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
