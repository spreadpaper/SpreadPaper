// SpreadPaper/Theme/CoolDarkComponents.swift

import SwiftUI
import PhosphorSwift

// MARK: - Custom Segmented Control

struct CoolDarkSegmentedControl: View {
    let options: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 1) {
            ForEach(options.indices, id: \.self) { index in
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selection = index } }) {
                    Text(options[index])
                        .font(.system(size: 10, weight: index == selection ? .semibold : .regular))
                        .foregroundStyle(index == selection ? .white : Color.cdTextTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(index == selection ? Color.cdAccent : Color.cdBgSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.cdBorder)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

// MARK: - Custom Text Field

struct CoolDarkTextField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .font(.system(size: 14))
            .foregroundStyle(Color.cdTextPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.cdBgPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.cdAccent : Color.cdBorder.opacity(0.6),
                            lineWidth: isFocused ? 1.5 : 1)
            )
            .animation(.easeInOut(duration: 0.12), value: isFocused)
    }
}

// MARK: - Custom Zoom Slider

struct CoolDarkSlider: View {
    @Binding var value: CGFloat
    var range: ClosedRange<CGFloat> = 0.1...5.0

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fraction = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let thumbX = fraction * width

            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.cdBorder)
                    .frame(height: 6)

                // Fill
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.cdAccent)
                    .frame(width: thumbX, height: 6)

                // Thumb
                Circle()
                    .fill(Color.white)
                    .stroke(Color.cdAccent, lineWidth: 2)
                    .frame(width: 16, height: 16)
                    .offset(x: thumbX - 8)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let fraction = max(0, min(1, drag.location.x / width))
                        value = range.lowerBound + CGFloat(fraction) * (range.upperBound - range.lowerBound)
                    }
            )
        }
        .frame(height: 16)
    }
}

// MARK: - Tooltip Overlay

struct FirstRunTooltip: View {
    let text: String
    @Binding var isVisible: Bool

    var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                // Arrow
                Triangle()
                    .fill(Color(hex: 0x333338))
                    .frame(width: 12, height: 6)

                // Body
                Text(text)
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: 0x333338))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            .onTapGesture { withAnimation { isVisible = false } }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Wallpaper Type Toggle

struct WallpaperTypeToggle: View {
    @Binding var selection: WallpaperType

    private let types: [(WallpaperType, String, String)] = [
        (.standard, "Static", "One image, spread across your displays."),
        (.appearance, "Themed", "Two images — one for Light mode, one for Dark mode."),
        (.dynamic, "Dynamic", "A schedule of images that shifts through the day.")
    ]

    private var description: String {
        types.first { $0.0 == selection }?.2 ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                ForEach(types, id: \.0) { type, label, _ in
                    Button(action: { selection = type }) {
                        Text(label)
                            .font(.system(size: 12, weight: type == selection ? .semibold : .regular))
                            .foregroundStyle(type == selection ? .white : Color.cdTextSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(type == selection ? Color.cdAccent : Color.cdBgElevated)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.cdBorder)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.cdBorder, lineWidth: 1)
            )

            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(Color.cdTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: 0.15), value: selection)
        }
    }
}

// MARK: - Toast

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.cdTextPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.cdBgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.cdBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

// MARK: - Dashed Add Button

struct DashedAddButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Spacer()
                Ph.plus.bold
                    .color(Color.cdTextTertiary)
                    .frame(width: 10, height: 10)
                Text(label.replacingOccurrences(of: "+ ", with: ""))
                    .font(.system(size: 11, weight: .medium))
                Spacer()
            }
            .foregroundStyle(Color.cdTextTertiary)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.cdBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chip Button Style (lightweight utility toggles)

struct CoolDarkChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.cdTextSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.cdBorder, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// MARK: - Ghost Button Style (secondary CTA with accent outline)

struct CoolDarkGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.cdAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.cdAccent.opacity(configuration.isPressed ? 0.15 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.cdAccent.opacity(0.5), lineWidth: 1)
            )
    }
}
