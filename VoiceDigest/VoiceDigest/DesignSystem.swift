import SwiftUI

// MARK: - Design System

/// VoiceDigest Premium Design System
/// Futuristic Minimalism: clean, airy, sophisticated with high-end typography

// MARK: - Color Palette

extension Color {
    /// Initialize color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

/// Semantic color palette for VoiceDigest
struct AppColors {
    /// Very light, almost white gray background
    static let background = Color(hex: "F8F9FA")

    /// Pure white card background
    static let cardBackground = Color.white

    /// Deep charcoal for primary text (not pure black)
    static let primaryText = Color(hex: "1A1A2E")

    /// Secondary text color
    static let secondaryText = Color(hex: "6B7280")

    /// Tertiary/muted text
    static let tertiaryText = Color(hex: "9CA3AF")

    /// Electric Indigo accent color
    static let accent = Color(hex: "5D5FEF")

    /// Teal secondary accent
    static let accentSecondary = Color(hex: "14B8A6")

    /// Subtle divider color
    static let divider = Color(hex: "E5E7EB")

    /// Category colors (more muted, sophisticated)
    static let categoryWork = Color(hex: "3B82F6")
    static let categoryPersonal = Color(hex: "10B981")
    static let categoryIdeas = Color(hex: "F59E0B")
    static let categoryTasks = Color(hex: "F97316")
    static let categoryUncategorized = Color(hex: "6B7280")

    /// Time of day colors
    static let morning = Color(hex: "FB923C")
    static let afternoon = Color(hex: "FBBF24")
    static let evening = Color(hex: "A78BFA")
    static let night = Color(hex: "6366F1")
}

// MARK: - Typography

struct AppTypography {
    /// Large display title (serif for newspaper feel)
    static let displaySerif = Font.system(size: 32, weight: .bold, design: .serif)

    /// Large title
    static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)

    /// Section header
    static let sectionHeader = Font.system(size: 20, weight: .semibold, design: .rounded)

    /// Card title
    static let cardTitle = Font.system(size: 17, weight: .semibold, design: .rounded)

    /// Body text
    static let body = Font.system(size: 15, weight: .regular, design: .default)

    /// Caption
    static let caption = Font.system(size: 13, weight: .medium, design: .rounded)

    /// Small caption
    static let captionSmall = Font.system(size: 11, weight: .medium, design: .rounded)

    /// Pill/tag text
    static let pill = Font.system(size: 12, weight: .medium, design: .rounded)
}

// MARK: - View Modifiers

/// Sophisticated card style with soft shadow
struct SophisticatedCardModifier: ViewModifier {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

/// Glassmorphism effect for headers
struct GlassmorphismModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Accent pill style (for tags, dates)
struct AccentPillModifier: ViewModifier {
    var color: Color = AppColors.accent
    var filled: Bool = false

    func body(content: Content) -> some View {
        content
            .font(AppTypography.pill)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(filled ? color : color.opacity(0.1))
            .foregroundStyle(filled ? .white : color)
            .clipShape(Capsule())
    }
}

/// Subtle tag style (low opacity background)
struct SubtleTagModifier: ViewModifier {
    var color: Color = AppColors.secondaryText

    func body(content: Content) -> some View {
        content
            .font(AppTypography.captionSmall)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.08))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

/// Quote block style for summaries
struct QuoteBlockModifier: ViewModifier {
    func body(content: Content) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(AppColors.accent)
                .frame(width: 3)
                .clipShape(Capsule())

            content
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply sophisticated card styling
    func sophisticatedCard(padding: CGFloat = 16, cornerRadius: CGFloat = 16) -> some View {
        modifier(SophisticatedCardModifier(padding: padding, cornerRadius: cornerRadius))
    }

    /// Apply glassmorphism effect
    func glassmorphism() -> some View {
        modifier(GlassmorphismModifier())
    }

    /// Apply accent pill style
    func accentPill(color: Color = AppColors.accent, filled: Bool = false) -> some View {
        modifier(AccentPillModifier(color: color, filled: filled))
    }

    /// Apply subtle tag style
    func subtleTag(color: Color = AppColors.secondaryText) -> some View {
        modifier(SubtleTagModifier(color: color))
    }

    /// Apply quote block style
    func quoteBlock() -> some View {
        modifier(QuoteBlockModifier())
    }
}

// MARK: - Custom Components

/// Checkmark circle for action items
struct ActionCheckmark: View {
    var isCompleted: Bool = false
    var color: Color = AppColors.accent

    var body: some View {
        ZStack {
            Circle()
                .fill(isCompleted ? color : color.opacity(0.15))
                .frame(width: 22, height: 22)

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .stroke(color.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
            }
        }
    }
}

/// Horizontal scrolling keyword pills
struct KeywordPillsView: View {
    let keywords: [String]
    var color: Color = AppColors.accent

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(keywords, id: \.self) { keyword in
                    Text(keyword)
                        .accentPill(color: color)
                }
            }
        }
    }
}

/// Watermark footer
struct WatermarkFooter: View {
    var text: String = "VoiceDigest Daily"

    var body: some View {
        HStack {
            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 1)

            Text(text)
                .font(AppTypography.captionSmall)
                .foregroundStyle(AppColors.tertiaryText)
                .padding(.horizontal, 12)

            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 1)
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Category Color Helper

extension NoteCategory {
    var sophisticatedColor: Color {
        switch self {
        case .work:
            return AppColors.categoryWork
        case .personal:
            return AppColors.categoryPersonal
        case .ideas:
            return AppColors.categoryIdeas
        case .tasks:
            return AppColors.categoryTasks
        case .uncategorized:
            return AppColors.categoryUncategorized
        }
    }
}

// MARK: - Time of Day Color Helper

extension TimeOfDay {
    var sophisticatedColor: Color {
        switch self {
        case .morning:
            return AppColors.morning
        case .afternoon:
            return AppColors.afternoon
        case .evening:
            return AppColors.evening
        case .night:
            return AppColors.night
        }
    }
}
