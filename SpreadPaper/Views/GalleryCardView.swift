// SpreadPaper/Views/GalleryCardView.swift

import SwiftUI
import PhosphorSwift

/// Preset card: thumbnail with applied pill and hover actions, plus name and kind badge.
struct GalleryCardView: View {
    let preset: SavedPreset
    let thumbnail: NSImage?
    /// True while this card's own thumbnail is still being rendered.
    var isThumbnailPending: Bool = false
    let isActive: Bool
    let isSelected: Bool
    let isApplying: Bool
    /// True while another preset is being applied; applies are serialized in the manager.
    var applyDisabled: Bool = false
    let onTap: () -> Void
    let onApply: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onRename: () -> Void
    let onRevealInFinder: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    private var showOverlay: Bool { isHovering || isSelected || isFocused }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            thumb
            metaRow
        }
        .contentShape(Rectangle())
        .onHover { hovering in isHovering = hovering }
        .onTapGesture { onTap() }
        .focusable()
        .focused($isFocused)
        .onKeyPress(.return) {
            guard !isApplying && !applyDisabled else { return .handled }
            onApply()
            return .handled
        }
        .onKeyPress(.space) {
            onTap()
            return .handled
        }
        .contextMenu { cardActions }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(preset.name)
        .accessibilityHint("Return applies this wallpaper, Space selects it")
        .accessibilityActions { cardActions }
    }

    /// The card's six actions, shared by the context menu and the
    /// accessibility rotor so the two cannot drift apart.
    @ViewBuilder
    private var cardActions: some View {
        Button("Apply") { onApply() }
        Button("Edit") { onEdit() }
        Button("Rename…") { onRename() }
        Button("Duplicate") { onDuplicate() }
        Button("Show in Finder") { onRevealInFinder() }
        Divider()
        Button("Delete", role: .destructive) { onDelete() }
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
            .animation(.easeOut(duration: 0.12), value: isFocused)
            .animation(.easeInOut(duration: 0.18), value: isActive)
    }

    private var ringColor: Color {
        (isActive || isSelected || isFocused) ? Color.cdAccent : Color.cdBorder
    }

    private var ringWidth: CGFloat {
        (isActive || isSelected || isFocused) ? 2 : 1
    }

    private var thumbnailImage: some View {
        ZStack {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isThumbnailPending {
                SkeletonBlock()
            } else {
                Color.cdBgElevated
                    .overlay {
                        Ph.image.regular
                            .cdIcon(Color.cdTextTertiary, size: 28)
                    }
                    .accessibilityElement()
                    .accessibilityLabel("No preview")
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
                .font(.cd(.caption, .semibold))
                .foregroundStyle(Color.cdTextPrimary)
        }
        .padding(EdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 7))
        .background(
            Capsule().fill(Color.cdOverlayScrim)
        )
        .background(
            Capsule().fill(.ultraThinMaterial)
        )
    }

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
                        .tint(Color.cdTextPrimary)
                } else {
                    Image(systemName: "checkmark")
                        .font(.cd(.subheadline, .bold))
                }
                Text(isApplying ? "Applying…" : "Apply")
            }
        }
        .buttonStyle(CoolDarkButtonStyle(isPrimary: true, size: .compact))
        .disabled(isApplying || applyDisabled)
    }

    private var editButton: some View {
        Button(action: onEdit) {
            HStack(spacing: 5) {
                Image(systemName: "pencil")
                    .font(.cd(.callout, .medium))
                Text("Edit")
            }
        }
        .buttonStyle(CoolDarkButtonStyle(size: .compact))
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
                .font(.cd(.body, .semibold))
                .foregroundStyle(Color.cdTextPrimary)
                .frame(width: 30, height: 30)
                .background(glassButtonBackground)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("More actions")
    }

    private var glassButtonBackground: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(Color.cdOverlayScrimSoft)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .fill(.ultraThinMaterial)
                    .opacity(0.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.cdHighlightStroke, lineWidth: 0.5)
            )
    }

    // MARK: - Meta row

    private var metaRow: some View {
        HStack(spacing: 8) {
            Text(preset.name)
                .font(.cd(.body, .semibold))
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
            Text(preset.kind.title)
                .font(.cd(.subheadline, .medium))
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

    private var typeIcon: some View {
        Image(systemName: preset.kind.systemImage)
            .font(.cd(.caption2, .semibold))
            .foregroundStyle(preset.kind.tint)
    }
}
