// SpreadPaper/Views/SpreadPhoto.swift

import SwiftUI

/// One panel's window onto a scene laid out across several panels side by side.
/// The gaps between panels belong to the scene, so it runs on behind them.
struct PanelSlice: Equatable {
    /// Size of the whole scene the panels are cut from.
    let spread: CGSize

    /// This panel's rectangle inside that scene.
    let frame: CGRect
}

/// Lays `content` out at the full spread size and shows only this panel's slice of it.
struct SpreadContent<Content: View>: View {
    let slice: PanelSlice
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(width: slice.spread.width, height: slice.spread.height)
            .offset(x: -slice.frame.minX, y: -slice.frame.minY)
            .frame(width: slice.frame.width, height: slice.frame.height, alignment: .topLeading)
            .clipped()
    }
}

/// The illustration photograph, spread across the panels and clipped to this one.
struct SpreadPhoto: View {
    let slice: PanelSlice

    var body: some View {
        SpreadContent(slice: slice) {
            Image(.heroBeach)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .accessibilityHidden(true)
        }
    }
}
