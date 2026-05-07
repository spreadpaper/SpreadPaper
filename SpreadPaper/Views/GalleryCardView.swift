// SpreadPaper/Views/GalleryCardView.swift

import SwiftUI
import PhosphorSwift

struct GalleryCardView: View {
    let preset: SavedPreset
    let thumbnail: NSImage?
    let isActive: Bool
    let isSelected: Bool
    let isApplying: Bool
    let onTap: () -> Void
    let onApply: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onRename: () -> Void
    let onRevealInFinder: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    private var showOverlay: Bool { isHovering || isSelected }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            thumb
            metaRow
        }
        .contentShape(Rectangle())
        .onHover { hovering in isHovering = hovering }
        .onTapGesture { onTap() }
        .contextMenu {
            Button("Apply") { onApply() }
            Button("Edit") { onEdit() }
            Button("Rename…") { onRename() }
            Button("Duplicate") { onDuplicate() }
            Button("Show in Finder") { onRevealInFinder() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    // MARK: - Thumbnail (16:10)

    private var thumb: some View {
        Color.clear
            .aspectRatio(16.0 / 10.0, contentMode: .fit)
            .overlay(thumbnailImage)
            .overlay(alignment: .topLeading) {
                if isActive {
                    appliedPill
                        .padding(8)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .overlay {
                if showOverlay {
                    hoverActions
                        .transition(.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ringColor, lineWidth: ringWidth)
            )
            .shadow(
                color: isActive ? Color.cdAccent.opacity(0.22)
                    : isSelected ? Color.cdAccent.opacity(0.22)
                    : .clear,
                radius: isActive ? 18 : 14,
                x: 0,
                y: isActive ? 6 : 4
            )
            .offset(y: isHovering ? -1 : 0)
            .animation(.easeOut(duration: 0.16), value: isHovering)
            .animation(.easeInOut(duration: 0.14), value: showOverlay)
            .animation(.easeInOut(duration: 0.18), value: isActive)
    }

    private var ringColor: Color {
        (isActive || isSelected) ? Color.cdAccent : Color.cdBorder
    }

    private var ringWidth: CGFloat {
        (isActive || isSelected) ? 2 : 1
    }

    private var thumbnailImage: some View {
        ZStack {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.cdBgElevated
                    .overlay {
                        Ph.image.regular
                            .color(Color.cdTextTertiary)
                            .frame(width: 28, height: 28)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: - Applied pill

    private var appliedPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.cdSuccess)
                .frame(width: 6, height: 6)
                .shadow(color: Color.cdSuccess.opacity(0.9), radius: 3)
            Text("Applied")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(EdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 7))
        .background(
            Capsule().fill(Color.black.opacity(0.55))
        )
        .background(
            Capsule().fill(.ultraThinMaterial)
        )
    }

    // MARK: - Hover actions

    // MARK: - Hover actions

    private var hoverActions: some View {
        HStack(spacing: 6) {
            applyButton
            editButton
            Spacer()
            moreButton
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    private var applyButton: some View {
        Button(action: onApply) {
            HStack(spacing: 5) {
                if isApplying {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }
                Text(isApplying ? "Applying…" : "Apply")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.cdAccent)
            )
            .shadow(color: Color.cdAccent.opacity(0.35), radius: 8, x: 0, y: 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isApplying)
    }

    private var editButton: some View {
        Button(action: onEdit) {
            HStack(spacing: 5) {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .medium))
                Text("Edit")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(glassButtonBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var moreButton: some View {
        Menu {
            Button("Rename…") { onRename() }
            Button("Duplicate") { onDuplicate() }
            Button("Show in Finder") { onRevealInFinder() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(glassButtonBackground)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var glassButtonBackground: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(Color.black.opacity(0.45))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .fill(.ultraThinMaterial)
                    .opacity(0.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.white.opacity(0.16), lineWidth: 0.5)
            )
    }

    // MARK: - Meta row

    private var metaRow: some View {
        HStack(spacing: 8) {
            Text(preset.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.cdTextPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            typeBadge
                .fixedSize()
        }
    }

    private var typeBadge: some View {
        HStack(spacing: 4) {
            typeIcon
                .frame(width: 10, height: 10)
            Text(typeBadgeLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.cdTextTertiary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.cdBgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.cdBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var typeIcon: some View {
        switch preset.wallpaperType {
        case "Dynamic":
            Ph.sun.regular.color(Color(hex: 0xf5a524))
        case "Light/Dark":
            Ph.circleHalf.regular.color(Color(hex: 0x7c7cff))
        default:
            Ph.image.regular.color(Color.cdTextTertiary)
        }
    }

    private var typeBadgeLabel: String {
        switch preset.wallpaperType {
        case "Dynamic":    return "Dynamic"
        case "Light/Dark": return "Light & Dark"
        default:           return "Static"
        }
    }
}
