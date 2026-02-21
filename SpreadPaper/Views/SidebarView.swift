import SwiftUI

struct SidebarView: View {
    @Binding var selectedPresetID: SavedPreset.ID?
    let presets: [SavedPreset]
    let onNewSetup: () -> Void
    let onDelete: (SavedPreset) -> Void

    var body: some View {
        List(selection: $selectedPresetID) {
            Section(header: Text("Saved Layouts")) {
                Button(action: onNewSetup) {
                    Label("New Setup", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.blue)

                ForEach(presets) { preset in
                    HStack {
                        Label(preset.name, systemImage: "photo")
                            .lineLimit(1)
                            .truncationMode(.tail)
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
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    }
}
