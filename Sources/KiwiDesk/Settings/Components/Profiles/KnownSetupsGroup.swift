import KiwiDeskCore
import SwiftUI

/// The Known screen setups card, last on Profiles (#3324): one row
/// per stored setup — one exact combination of screens — each
/// forgettable on its own, modelled on Wi-Fi's Known Networks. The
/// connected setup's ✕ greys, since the next Save would write it
/// back; Core refuses it as well.
struct KnownSetupsGroup: View {
    @ObservedObject var model: SettingsModel
    @State private var expanded = false

    var body: some View {
        SettingsDisclosure(
            SettingsCatalog.profiles.knownSetups,
            chrome: .card,
            isExpanded: $expanded,
            summary: L(
                "profiles.known.count",
                "setups: %1$d",
                model.knownSetups.count
            )
        ) {
            VStack(alignment: .leading, spacing: 8) {
                // Drawn in both states, so a search hit on Forget
                // lands once, here (#1250).
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .searchAnchored(
                        SettingsCatalog.profiles.knownSetups.children
                            .forget
                    )
                ForEach(model.knownSetups, id: \.self) { setup in
                    row(setup)
                }
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var caption: String {
        model.knownSetups.isEmpty
            ? L(
                "profiles.known.empty",
                "No screen setups remembered yet. A profile remembers "
                    + "one when you save or load it."
            )
            : L(
                "profiles.known.caption",
                "Screen combinations your profiles remember. Forget one "
                    + "you won't use again; your other setups stay as "
                    + "they are."
            )
    }

    private func row(_ setup: KnownMonitorSet) -> some View {
        let label = model.knownSetupLabel(setup)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 10) {
                readout(setup, label: label)
                Spacer()
                forgetButton(setup, label: label)
            }
            // The greyed ✕'s reason, its own element outside the
            // dim (gui.md ▸ a dim is not a sentence).
            if setup.isConnected {
                Text(Self.connectedReason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, Self.textIndent)
            }
        }
        .contentShape(Rectangle())
        // The connected row has nothing to do from the keyboard.
        .focusable(!setup.isConnected)
        .rowActions {
            // A menu row: the style is the menu's.
            Button(
                SettingsCatalog.profiles.knownSetups.children.forget.text
            ) {
                model.confirmingSetupForget(setup)
            }
            .buttonStyle(.plain)
            .disabled(setup.isConnected)
        }
    }

    /// Glyph to text column: the glyph's frame and the row spacing.
    private static let textIndent: CGFloat = 36

    /// The glyph, name, detail and chip, spoken as one element; the
    /// ✕ beside it stays its own (`DesktopsGroup+Setups`'s shape).
    private func readout(
        _ setup: KnownMonitorSet,
        label: String
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "display")
                .foregroundStyle(.secondary)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail(setup))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if setup.isConnected {
                BadgeChip(label: Self.connectedChip)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L("profiles.sets.chip.ax", "Screen setup: %1$@", label)
        )
        .accessibilityValue(
            setup.isConnected
                ? LocalizedList.join([detail(setup), Self.connectedChip])
                : detail(setup)
        )
    }

    private static var connectedChip: String {
        L("profiles.sets.connected", "connected")
    }

    /// "2 screens · in “Cowork”": the page's own screen count
    /// phrase, then the holder.
    private func detail(_ setup: KnownMonitorSet) -> String {
        L(
            "profiles.known.detail",
            "%1$@ · in “%2$@”",
            screensPhrase(setup.monitors.count),
            setup.profile
        )
    }

    private func forgetButton(
        _ setup: KnownMonitorSet,
        label: String
    ) -> some View {
        let name = L("profiles.known.forget.help", "Forget %1$@", label)
        return Button {
            model.confirmingSetupForget(setup)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .disabled(setup.isConnected)
        .iconHoverChip()
        // Named by its act, connected or not; the reason is help.
        .help(setup.isConnected ? Self.connectedReason : name)
        .accessibilityLabel(name)
    }

    private static var connectedReason: String {
        L(
            "profiles.known.connected.help",
            "Disconnect these screens to forget this setup."
        )
    }
}
