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
                aboutSection
            }
            .padding(16)
        }
    }

    /// About (#68 §3.9): the canonical logo + name + version
    /// placement (the glyph is the reserved branding slot,
    /// §3.8 — swapped for the real logo once it exists) and
    /// the discreet support link.
    private var aboutSection: some View {
        SettingsSection("About") {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("KiwiDesk")
                        .font(.headline)
                    Text(KiwiDeskVersion.displayString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                Link(destination: SupportLinks.koFi) {
                    Label(
                        "Support KiwiDesk",
                        systemImage: "heart"
                    )
                }
                .font(.callout)
            }
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
