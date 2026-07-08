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

    /// About (#68 §3.9): the wordmark as the canonical logo +
    /// name placement, version and the discreet support link
    /// beneath. Falls back to the pre-logo glyph row when the
    /// bundled resource is missing.
    private var aboutSection: some View {
        SettingsSection("About") {
            VStack(spacing: 10) {
                aboutBrand
                Text(KiwiDeskVersion.displayString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Link(destination: SupportLinks.koFi) {
                    Label(
                        "Support KiwiDesk",
                        systemImage: "heart"
                    )
                }
                .font(.callout)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// The wordmark rides a fixed light badge: its navy text
    /// is fused into the artwork's compound path, so it
    /// cannot follow the appearance — the badge keeps it
    /// readable in dark mode and melts into a light pane.
    @ViewBuilder private var aboutBrand: some View {
        if let wordmark = BrandAssets.wordmark {
            Image(nsImage: wordmark)
                .resizable()
                .scaledToFit()
                .frame(height: 130)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Self.badge)
                )
        } else {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                Text("KiwiDesk")
                    .font(.headline)
            }
        }
    }

    /// Off-white with a whisper of the logo's cream green.
    private static let badge = Color(
        red: 0.965,
        green: 0.976,
        blue: 0.945
    )

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
