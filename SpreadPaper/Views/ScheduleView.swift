// SpreadPaper/Views/ScheduleView.swift

import AppKit
import SwiftUI
import PhosphorSwift

// MARK: - Schedule Entry Text

/// Copy a schedule entry reads out, kept pure so it can be unit tested.
/// Times arrive as minutes since midnight.
nonisolated enum ScheduleEntryText {
    /// Place names for the sixteen images a dynamic preset can hold.
    private static let ordinals = [
        "First", "Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eighth",
        "Ninth", "Tenth", "Eleventh", "Twelfth", "Thirteenth", "Fourteenth", "Fifteenth", "Sixteenth"
    ]

    /// Counts spelled out, matching the place names above.
    private static let cardinals = [
        "one", "two", "three", "four", "five", "six", "seven", "eight",
        "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen"
    ]

    /// Where an entry sits in the schedule, for example `Third of four`.
    /// Places past the spelled range fall back to digits.
    static func position(index: Int, count: Int) -> String {
        guard count > 1 else { return "Only image" }
        let place = ordinals.indices.contains(index) ? ordinals[index] : "\(index + 1)"
        let total = cardinals.indices.contains(count - 1) ? cardinals[count - 1] : "\(count)"
        return "\(place) of \(total)"
    }

    /// What takes over when an entry ends, named by the time it starts.
    /// A next start earlier than this one belongs to the day after.
    static func handover(start: Int, next: Int, isOnly: Bool, locale: Locale = .current) -> String {
        guard !isOnly else { return "Shows all day as the only image in the schedule." }
        let time = TimeVariant.clockString(hour: next / 60, minute: next % 60, locale: locale)
        guard next < start else { return "Shows until the next image at \(time)." }
        return "Shows until the first image at \(time) tomorrow."
    }
}

// MARK: - Centered Detail Modal

/// Centered sheet naming one schedule entry and setting the time it starts.
/// The image that follows is stated, not offered as a field.
struct ScheduleDetailModal: View {
    @Binding var variant: TimeVariant
    let defaultName: String
    let nextVariant: TimeVariant
    let imageURL: URL?
    let position: Int
    let count: Int
    let onRemove: () -> Void
    let onDone: () -> Void

    @State private var thumbnail: CGImage?
    @State private var confirmingRemove = false

    /// Size of the entry thumbnail, in points.
    private static let thumbnailSize = CGSize(width: 72, height: 45)

    /// Headroom over the thumbnail's longest side, so a wide source still fills it.
    private static let thumbnailOversample: CGFloat = 2

    var body: some View {
        ZStack {
            Color.cdOverlayScrim
                .ignoresSafeArea()
                .onTapGesture { onDone() }

            VStack(spacing: 0) {
                header
                Divider().overlay(Color.cdBorder)
                fields
                Divider().overlay(Color.cdBorder)
                footer
            }
            .frame(width: 420)
            .background(Color.cdBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: CoolDarkMetrics.dialogCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: CoolDarkMetrics.dialogCornerRadius)
                    .stroke(Color.cdBorder, lineWidth: 1)
            )
            .shadow(color: .cdShadow, radius: 20)
            .confirmationDialog(
                "Remove this image from the schedule?",
                isPresented: $confirmingRemove
            ) {
                Button("Remove", role: .destructive) { onRemove() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("The schedule loses this entry. The image file stays where it is.")
            }
        }
        .task(id: imageURL) { await loadThumbnail() }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Edit schedule entry")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.cdTextPrimary)
            Spacer(minLength: 0)
            Text(ScheduleEntryText.position(index: position, count: count))
                .font(.system(size: 12))
                .foregroundStyle(Color.cdTextTertiary)
                .lineLimit(1)
        }
        .padding(CoolDarkMetrics.dialogPadding)
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: CoolDarkMetrics.sectionGap) {
            VStack(alignment: .leading, spacing: CoolDarkMetrics.labelGap) {
                SectionHeader(title: "Image")
                imageSummary
            }

            VStack(alignment: .leading, spacing: CoolDarkMetrics.labelGap) {
                SectionHeader(title: "Starts at")
                HStack(alignment: .center, spacing: 14) {
                    startTimeField
                    Text(handover)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.cdTextTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }

            VStack(alignment: .leading, spacing: CoolDarkMetrics.labelGap) {
                SectionHeader(title: "Name")
                CoolDarkTextField(placeholder: defaultName, text: $variant.name)
            }
        }
        .padding(CoolDarkMetrics.dialogPadding)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button("Remove") { confirmingRemove = true }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.cdDanger)
                .frame(height: CoolDarkMetrics.compactControlHeight)
                .contentShape(Rectangle())

            Spacer(minLength: 0)

            Button("Done", action: onDone)
                .buttonStyle(CoolDarkButtonStyle(isPrimary: true, size: .compact))
        }
        .padding(.horizontal, CoolDarkMetrics.dialogPadding)
        .padding(.vertical, 14)
    }

    /// Clock the entry starts on, on the same grid as the name field below it.
    private var startTimeField: some View {
        CoolDarkTimeField(minutes: startMinutes, label: "Starts at")
            .fixedSize()
    }

    /// Thumbnail and file name for the image being timed.
    private var imageSummary: some View {
        HStack(spacing: 12) {
            thumbnailView
            Text(entryName)
                .font(.system(size: CoolDarkMetrics.fieldFontSize, weight: .medium))
                .foregroundStyle(Color.cdTextPrimary)
                .lineLimit(2)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }

    /// The rendered thumbnail, or a framed glyph while it loads or when the file is gone.
    private var thumbnailView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CoolDarkMetrics.controlCornerRadius)
                .fill(Color.cdBgPrimary)
            if let thumbnail {
                Image(decorative: thumbnail, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Ph.image.regular
                    .cdIcon(Color.cdTextTertiary, size: 16)
            }
        }
        .frame(width: Self.thumbnailSize.width, height: Self.thumbnailSize.height)
        .clipShape(RoundedRectangle(cornerRadius: CoolDarkMetrics.controlCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: CoolDarkMetrics.controlCornerRadius)
                .stroke(Color.cdBorder, lineWidth: 1)
        )
    }

    // MARK: - Values

    /// Start time as minutes since midnight, written back as an hour and a minute.
    private var startMinutes: Binding<Int> {
        Binding(
            get: { variant.hour * 60 + variant.minute },
            set: { newValue in
                let minute = TimeFieldMath.wrapped(newValue)
                variant.hour = minute / 60
                variant.minute = minute % 60
            }
        )
    }

    /// Heading for the image: what it is called now, else what its file is called.
    private var entryName: String {
        variant.name.isEmpty ? defaultName : variant.name
    }

    /// Sentence naming the image that takes over from this one.
    private var handover: String {
        ScheduleEntryText.handover(
            start: variant.hour * 60 + variant.minute,
            next: nextVariant.hour * 60 + nextVariant.minute,
            isOnly: count <= 1
        )
    }

    /// Renders the entry's thumbnail off the main actor.
    /// An unreadable file leaves the glyph in place.
    private func loadThumbnail() async {
        thumbnail = nil
        guard let imageURL else { return }
        let flipped = variant.isFlipped
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let longestSide = max(Self.thumbnailSize.width, Self.thumbnailSize.height)
        let maxPixelSize = Int((longestSide * Self.thumbnailOversample * scale).rounded())
        thumbnail = await Task.detached(priority: .userInitiated) {
            ThumbnailRenderer.thumbnail(for: imageURL, maxPixelSize: maxPixelSize, flipped: flipped)
        }.value
    }
}
