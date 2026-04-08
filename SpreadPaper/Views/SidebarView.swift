import SwiftUI

struct SidebarView: View {
    @Binding var selectedPresetID: SavedPreset.ID?
    let presets: [SavedPreset]
    let onNewSetup: () -> Void
    let onNewDynamicSetup: () -> Void
    let onDelete: (SavedPreset) -> Void

    var body: some View {
        List(selection: $selectedPresetID) {
            Section(header: Text("Saved Layouts")) {
                Button(action: onNewSetup) {
                    Label("New Setup", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.blue)

                Button(action: onNewDynamicSetup) {
                    Label("New Dynamic Setup", systemImage: "sun.max")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.orange)

                ForEach(presets) { preset in
                    HStack {
                        Label(preset.name, systemImage: preset.isDynamic ? "sun.max" : "photo")
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if preset.isDynamic {
                            Text("Dynamic")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }
                    .tag(preset.id)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            onDelete(preset)
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet { onDelete(presets[index]) }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
    }
}
