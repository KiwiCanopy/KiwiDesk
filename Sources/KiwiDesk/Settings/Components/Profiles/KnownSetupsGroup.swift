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
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(model.knownSetups, id: \.monitors) { setup in
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
        return HStack(alignment: .center, spacing: 10) {
            Image(
                systemName: setup.monitors.count > 1
                    ? "display.2" : "display"
            )
            .foregroundStyle(.secondary)
            .frame(width: 26)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail(setup))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                // The greyed ✕'s reason, drawn outside the dim
                // (gui.md ▸ a dim is not a sentence).
                if setup.isConnected {
                    Text(Self.connectedReason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if setup.isConnected {
                BadgeChip(
                    label: L("profiles.known.connected", "connected")
                )
            }
            Spacer()
            forgetButton(setup, label: label)
        }
        .contentShape(Rectangle())
        .focusable()
        .accessibilityElement(children: .combine)
        .rowActions {
            // A menu row: the style is the menu's.
            Button(forgetTitle) {
                model.confirmingSetupForget(setup)
            }
            .buttonStyle(.plain)
            .disabled(setup.isConnected)
        }
        .searchAnchored(SettingsCatalog.profiles.knownSetups.children.forget)
    }

    private var forgetTitle: String {
        SettingsCatalog.profiles.knownSetups.children.forget.text
    }

    /// "2 screens · in “Cowork”" — the count leads, as the ruled
    /// copy does, one form per count.
    private func detail(_ setup: KnownMonitorSet) -> String {
        setup.monitors.count == 1
            ? L(
                "profiles.known.detail.one",
                "1 screen · in “%1$@”",
                setup.profile
            )
            : L(
                "profiles.known.detail.many",
                "%1$d screens · in “%2$@”",
                setup.monitors.count,
                setup.profile
            )
    }

    private func forgetButton(
        _ setup: KnownMonitorSet,
        label: String
    ) -> some View {
        Button {
            model.confirmingSetupForget(setup)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .disabled(setup.isConnected)
        .iconButtonAffordance(
            setup.isConnected
                ? Self.connectedReason
                : L(
                    "profiles.known.forget.help",
                    "Forget %1$@",
                    label
                )
        )
    }

    private static var connectedReason: String {
        L(
            "profiles.known.connected.help",
            "Disconnect these screens to forget this setup."
        )
    }
}
