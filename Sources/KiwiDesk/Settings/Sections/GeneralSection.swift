import KiwiDeskCore
import SwiftUI

/// Whole App ▸ General (#68 §3.2): genuinely app-wide state,
/// never affected by which profile the banner has open — the
/// Advanced config-file tools (and, later passes, the error
/// surface entry and About area).
struct GeneralSection: View {
    @ObservedObject var model: SettingsModel
    /// Advanced is collapsed by default — only interested
    /// users need the config-file path and the raw editor.
    @State private var advancedExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                advancedSection
            }
            .padding(16)
        }
    }

    private var advancedSection: some View {
        DisclosureGroup(isExpanded: $advancedExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Configuration file")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    Text(model.configURL.path)
                        .font(
                            .system(
                                .body,
                                design: .monospaced
                            )
                        )
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Reveal") {
                        NSWorkspace.shared
                            .activateFileViewerSelecting(
                                [model.configURL]
                            )
                    }
                }
                Divider()
                Button {
                    model.showLuaEditor = true
                } label: {
                    Label(
                        "Edit init.lua directly",
                        systemImage: "curlybraces"
                    )
                }
                Text(
                    "Opens the integrated Lua editor for "
                        + "custom scripting beyond the visual "
                        + "controls."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("Advanced").font(.headline)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
