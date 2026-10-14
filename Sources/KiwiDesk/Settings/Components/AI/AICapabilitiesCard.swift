import KiwiDeskCore
import SwiftUI

/// AI ▸ What it can do: one line per capability the MCP tools
/// have, never one ahead of its tool, then the two facts a user
/// must meet on the page itself, never only behind a `?`
/// (`ui-patterns.md`).
struct AICapabilitiesCard: View {
    var body: some View {
        SettingsSection(SettingsCatalog.ai.capabilitiesCard) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Self.lines, id: \.self) { line in
                    Label(line, systemImage: "checkmark")
                        .labelStyle(CapabilityLabelStyle())
                }
                Divider().padding(.vertical, 4)
                Text(keepFact)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(privacyFact)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @MainActor static var lines: [String] {
        [
            L(
                "ai.capability.windows",
                "Tile, float, swap and move your windows."
            ),
            L(
                "ai.capability.spaces",
                "Switch, create and move Spaces, and change their "
                    + "layouts."
            ),
            L(
                "ai.capability.settings",
                "Change gaps, borders and the bars on KiwiShelf."
            ),
            L(
                "ai.capability.looks",
                "Make, wear and save looks, matched to your "
                    + "wallpaper from a screenshot."
            ),
            L(
                "ai.capability.inspect",
                "See your Spaces and windows, and look up any "
                    + "command."
            ),
        ]
    }

    private var keepFact: String {
        L(
            "ai.fact.keep",
            "Setting changes stay temporary until you say "
                + "\u{201C}keep\u{201D}."
        )
    }

    private var privacyFact: String {
        L(
            "ai.fact.privacy",
            "Your AI app can read your window titles, and sends "
                + "what it reads to the AI model it uses."
        )
    }
}

/// A capability line: the mark in secondary ink beside the text.
private struct CapabilityLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            configuration.title
        }
    }
}
