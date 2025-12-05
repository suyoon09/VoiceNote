import UIKit
import PDFKit

struct PDFGenerator {
    // MARK: - PDF Configuration

    private struct Config {
        static let pageWidth: CGFloat = 612  // US Letter
        static let pageHeight: CGFloat = 792
        static let marginHorizontal: CGFloat = 50
        static let marginTop: CGFloat = 60
        static let marginBottom: CGFloat = 50

        static var contentWidth: CGFloat {
            pageWidth - (marginHorizontal * 2)
        }
    }

    // MARK: - Colors

    private static let primaryColor = UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0)
    private static let secondaryColor = UIColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1.0)
    private static let accentColor = UIColor(red: 0.0, green: 0.6, blue: 0.8, alpha: 1.0)
    private static let dividerColor = UIColor(red: 0.9, green: 0.9, blue: 0.92, alpha: 1.0)

    // MARK: - Public API

    static func generatePDF(from note: VoiceNote) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: Config.pageWidth, height: Config.pageHeight))

        return renderer.pdfData { context in
            context.beginPage()

            var yPosition = Config.marginTop

            // Draw header
            yPosition = drawHeader(note: note, at: yPosition, in: context.cgContext)

            // Draw divider
            yPosition = drawDivider(at: yPosition + 20, in: context.cgContext)

            // Draw metadata
            yPosition = drawMetadata(note: note, at: yPosition + 25, in: context.cgContext)

            // Draw content
            yPosition = drawContent(note: note, at: yPosition + 30, in: context.cgContext)

            // Draw keywords if present
            if !note.keywords.isEmpty {
                yPosition = drawKeywords(note: note, at: yPosition + 25, in: context.cgContext)
            }

            // Draw footer
            drawFooter(in: context.cgContext)
        }
    }

    static func generateDigestPDF(from digest: DailyDigest) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: Config.pageWidth, height: Config.pageHeight))

        return renderer.pdfData { context in
            context.beginPage()

            var yPosition = Config.marginTop

            // Draw digest header
            yPosition = drawDigestHeader(digest: digest, at: yPosition, in: context.cgContext)

            // Draw divider
            yPosition = drawDivider(at: yPosition + 20, in: context.cgContext)

            // Draw summary
            yPosition = drawDigestSummary(digest: digest, at: yPosition + 25, in: context.cgContext)

            // Draw notes section
            if !digest.notes.isEmpty {
                yPosition = drawNotesSection(notes: digest.notes, at: yPosition + 30, in: context.cgContext, context: context)
            }

            // Draw footer
            drawFooter(in: context.cgContext)
        }
    }

    // MARK: - Header Drawing

    private static func drawHeader(note: VoiceNote, at yPosition: CGFloat, in cgContext: CGContext) -> CGFloat {
        var y = yPosition

        // Date - Large, elegant
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        let dateString = dateFormatter.string(from: note.createdAt)

        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: primaryColor,
            .kern: 0.5
        ]

        let dateRect = CGRect(x: Config.marginHorizontal, y: y, width: Config.contentWidth, height: 35)
        dateString.draw(in: dateRect, withAttributes: dateAttributes)
        y += 40

        // Time
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: note.createdAt)

        let timeAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: secondaryColor,
            .kern: 1.0
        ]

        let timeRect = CGRect(x: Config.marginHorizontal, y: y, width: Config.contentWidth, height: 20)
        timeString.uppercased().draw(in: timeRect, withAttributes: timeAttributes)
        y += 20

        return y
    }

    private static func drawDigestHeader(digest: DailyDigest, at yPosition: CGFloat, in cgContext: CGContext) -> CGFloat {
        var y = yPosition

        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: accentColor,
            .kern: 2.0
        ]

        let titleRect = CGRect(x: Config.marginHorizontal, y: y, width: Config.contentWidth, height: 18)
        "DAILY DIGEST".draw(in: titleRect, withAttributes: titleAttributes)
        y += 25

        // Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        let dateString = dateFormatter.string(from: digest.date)

        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: primaryColor,
            .kern: 0.5
        ]

        let dateRect = CGRect(x: Config.marginHorizontal, y: y, width: Config.contentWidth, height: 35)
        dateString.draw(in: dateRect, withAttributes: dateAttributes)
        y += 40

        // Note count
        let countString = "\(digest.noteCount) voice note\(digest.noteCount == 1 ? "" : "s")"
        let countAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: secondaryColor
        ]

        let countRect = CGRect(x: Config.marginHorizontal, y: y, width: Config.contentWidth, height: 20)
        countString.draw(in: countRect, withAttributes: countAttributes)
        y += 20

        return y
    }

    // MARK: - Metadata Drawing

    private static func drawMetadata(note: VoiceNote, at yPosition: CGFloat, in cgContext: CGContext) -> CGFloat {
        var y = yPosition

        // Category badge
        let categoryString = note.category.rawValue.uppercased()
        let categoryAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: accentColor,
            .kern: 1.5
        ]

        let categoryRect = CGRect(x: Config.marginHorizontal, y: y, width: Config.contentWidth, height: 16)
        categoryString.draw(in: categoryRect, withAttributes: categoryAttributes)
        y += 20

        // Duration
        let durationString = formatDuration(note.duration)
        let durationAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: secondaryColor
        ]

        let durationRect = CGRect(x: Config.marginHorizontal, y: y, width: Config.contentWidth, height: 16)
        "Duration: \(durationString)".draw(in: durationRect, withAttributes: durationAttributes)
        y += 16

        return y
    }

    // MARK: - Content Drawing

    private static func drawContent(note: VoiceNote, at yPosition: CGFloat, in cgContext: CGContext) -> CGFloat {
        var y = yPosition

        // Section label
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: secondaryColor,
            .kern: 1.0
        ]

        let labelRect = CGRect(x: Config.marginHorizontal, y: y, width: Config.contentWidth, height: 16)
        "TRANSCRIPT".draw(in: labelRect, withAttributes: labelAttributes)
        y += 25

        // Content text
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: primaryColor,
            .paragraphStyle: createParagraphStyle(lineHeight: 20)
        ]

        let content = note.cleanedContent.isEmpty ? note.rawTranscript : note.cleanedContent
        let contentSize = content.boundingRect(
            with: CGSize(width: Config.contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: contentAttributes,
            context: nil
        )

        let contentRect = CGRect(x: Config.marginHorizontal, y: y, width: Config.contentWidth, height: contentSize.height)
        content.draw(in: contentRect, withAttributes: contentAttributes)
        y += contentSize.height

        return y
    }

    private static func drawDigestSummary(digest: DailyDigest, at yPosition: CGFloat, in cgContext: CGContext) -> CGFloat {
        var y = yPosition

        // Section label
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: secondaryColor,
            .kern: 1.0
        ]

        let labelRect = CGRect(x: Config.marginHorizontal, y: y, width: Config.contentWidth, height: 16)
        "SUMMARY".draw(in: labelRect, withAttributes: labelAttributes)
        y += 25

        // Summary text
        let summaryAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: primaryColor,
            .paragraphStyle: createParagraphStyle(lineHeight: 20)
        ]

        let summarySize = digest.summary.boundingRect(
            with: CGSize(width: Config.contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: summaryAttributes,
            context: nil
        )

        let summaryRect = CGRect(x: Config.marginHorizontal, y: y, width: Config.contentWidth, height: summarySize.height)
        digest.summary.draw(in: summaryRect, withAttributes: summaryAttributes)
        y += summarySize.height

        return y
    }

    private static func drawNotesSection(notes: [VoiceNote], at yPosition: CGFloat, in cgContext: CGContext, context: UIGraphicsPDFRendererContext) -> CGFloat {
        var y = yPosition

        // Section label
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: secondaryColor,
            .kern: 1.0
        ]

        let labelRect = CGRect(x: Config.marginHorizontal, y: y, width: Config.contentWidth, height: 16)
        "NOTES".draw(in: labelRect, withAttributes: labelAttributes)
        y += 25

        for note in notes {
            // Check if we need a new page
            if y > Config.pageHeight - 150 {
                context.beginPage()
                y = Config.marginTop
            }

            y = drawNoteItem(note: note, at: y, in: cgContext)
            y += 15
        }

        return y
    }

    private static func drawNoteItem(note: VoiceNote, at yPosition: CGFloat, in cgContext: CGContext) -> CGFloat {
        var y = yPosition

        // Time
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: note.createdAt)

        let timeAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: accentColor
        ]

        let timeRect = CGRect(x: Config.marginHorizontal, y: y, width: Config.contentWidth, height: 14)
        timeString.draw(in: timeRect, withAttributes: timeAttributes)
        y += 16

        // Content preview
        let content = note.cleanedContent.isEmpty ? note.rawTranscript : note.cleanedContent
        let preview = String(content.prefix(200)) + (content.count > 200 ? "..." : "")

        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: primaryColor,
            .paragraphStyle: createParagraphStyle(lineHeight: 16)
        ]

        let contentSize = preview.boundingRect(
            with: CGSize(width: Config.contentWidth, height: 60),
            options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine],
            attributes: contentAttributes,
            context: nil
        )

        let contentRect = CGRect(x: Config.marginHorizontal, y: y, width: Config.contentWidth, height: min(contentSize.height, 60))
        preview.draw(in: contentRect, withAttributes: contentAttributes)
        y += min(contentSize.height, 60)

        return y
    }

    // MARK: - Keywords Drawing

    private static func drawKeywords(note: VoiceNote, at yPosition: CGFloat, in cgContext: CGContext) -> CGFloat {
        var y = yPosition

        // Section label
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: secondaryColor,
            .kern: 1.0
        ]

        let labelRect = CGRect(x: Config.marginHorizontal, y: y, width: Config.contentWidth, height: 16)
        "KEYWORDS".draw(in: labelRect, withAttributes: labelAttributes)
        y += 22

        // Keywords as comma-separated list
        let keywordsString = note.keywords.prefix(8).joined(separator: "  |  ")
        let keywordsAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: accentColor
        ]

        let keywordsRect = CGRect(x: Config.marginHorizontal, y: y, width: Config.contentWidth, height: 16)
        keywordsString.draw(in: keywordsRect, withAttributes: keywordsAttributes)
        y += 16

        return y
    }

    // MARK: - Divider Drawing

    private static func drawDivider(at yPosition: CGFloat, in cgContext: CGContext) -> CGFloat {
        cgContext.setStrokeColor(dividerColor.cgColor)
        cgContext.setLineWidth(1.0)
        cgContext.move(to: CGPoint(x: Config.marginHorizontal, y: yPosition))
        cgContext.addLine(to: CGPoint(x: Config.pageWidth - Config.marginHorizontal, y: yPosition))
        cgContext.strokePath()
        return yPosition
    }

    // MARK: - Footer Drawing

    private static func drawFooter(in cgContext: CGContext) {
        let footerY = Config.pageHeight - Config.marginBottom

        // Divider line
        cgContext.setStrokeColor(dividerColor.cgColor)
        cgContext.setLineWidth(0.5)
        cgContext.move(to: CGPoint(x: Config.marginHorizontal, y: footerY - 15))
        cgContext.addLine(to: CGPoint(x: Config.pageWidth - Config.marginHorizontal, y: footerY - 15))
        cgContext.strokePath()

        // Footer text
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: UIColor(red: 0.7, green: 0.7, blue: 0.72, alpha: 1.0),
            .kern: 0.5
        ]

        let footerText = "Generated by VoiceDigest"
        let footerSize = footerText.size(withAttributes: footerAttributes)
        let footerX = (Config.pageWidth - footerSize.width) / 2
        let footerRect = CGRect(x: footerX, y: footerY, width: footerSize.width, height: footerSize.height)
        footerText.draw(in: footerRect, withAttributes: footerAttributes)
    }

    // MARK: - Helpers

    private static func createParagraphStyle(lineHeight: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineHeight - 12
        style.paragraphSpacing = 8
        return style
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}
