import SwiftUI

extension View {
    @ViewBuilder
    func adaptiveGlass<S: Shape>(in shape: S) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
        #else
        self.background(.ultraThinMaterial, in: shape)
        #endif
    }
}
