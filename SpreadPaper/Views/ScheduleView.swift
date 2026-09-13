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

// MARK: - Schedule Clock

/// Wall-clock conversion between a stored hour and minute and the date a picker binds to.
/// One UTC day carries every time, so no daylight saving shift can move one.
nonisolated enum ScheduleClock {
    /// Calendar the picker reads and the conversion writes.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// Date on the reference day carrying the given wall-clock time.
    /// Values outside a day clamp into one.
    static func date(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2001
        components.month = 1
        components.day = 1
        components.hour = min(max(hour, 0), 23)
        components.minute = min(max(minute, 0), 59)
        return calendar.date(from: components) ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    /// Hour and minute read back off a date.
    static func time(from date: Date) -> (hour: Int, minute: Int) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0, parts.minute ?? 0)
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
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
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
        HStack {
            Text("Edit schedule entry")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.cdTextPrimary)
            Spacer()
        }
        .padding(20)
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 20) {
            imageSummary

            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Name")
                CoolDarkTextField(placeholder: defaultName, text: $variant.name)
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Starts at")
                DatePicker("", selection: startTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.stepperField)
                    .labelsHidden()
                    .environment(\.calendar, ScheduleClock.calendar)
                    .environment(\.timeZone, ScheduleClock.calendar.timeZone)
                    .accessibilityLabel("Starts at")
                Text(handover)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.cdTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
    }

    private var footer: some View {
        HStack {
            Button("Remove") { confirmingRemove = true }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.cdDanger)

            Spacer()

            Button("Done", action: onDone)
                .buttonStyle(CoolDarkButtonStyle(isPrimary: true, size: .compact))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    /// Thumbnail, name and place in the schedule for the image being timed.
    private var imageSummary: some View {
        HStack(spacing: 12) {
            thumbnailView
            VStack(alignment: .leading, spacing: 3) {
                Text(entryName)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Color.cdTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(ScheduleEntryText.position(index: position, count: count))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.cdTextTertiary)
            }
            Spacer(minLength: 0)
        }
    }

    /// The rendered thumbnail, or a framed glyph while it loads or when the file is gone.
    private var thumbnailView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
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
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.cdBorder, lineWidth: 1)
        )
    }

    // MARK: - Values

    /// Start time as a date, written back as the stored hour and minute.
    private var startTime: Binding<Date> {
        Binding(
            get: { ScheduleClock.date(hour: variant.hour, minute: variant.minute) },
            set: { newValue in
                let time = ScheduleClock.time(from: newValue)
                variant.hour = time.hour
                variant.minute = time.minute
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
