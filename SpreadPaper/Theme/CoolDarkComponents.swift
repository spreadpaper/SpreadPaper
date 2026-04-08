// SpreadPaper/Theme/CoolDarkComponents.swift

import SwiftUI

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

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(Color.cdTextPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.cdBgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.cdBorder, lineWidth: 1)
            )
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
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.cdBorder)
                    .frame(height: 4)

                // Fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.cdAccent)
                    .frame(width: thumbX, height: 4)

                // Thumb
                Circle()
                    .fill(Color.white)
                    .stroke(Color.cdAccent, lineWidth: 1.5)
                    .frame(width: 12, height: 12)
                    .offset(x: thumbX - 6)
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
        .frame(height: 12)
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

// MARK: - Dashed Add Button

struct DashedAddButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.cdTextTertiary)
                Spacer()
            }
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .foregroundStyle(Color.cdBorder)
            )
        }
        .buttonStyle(.plain)
    }
}
