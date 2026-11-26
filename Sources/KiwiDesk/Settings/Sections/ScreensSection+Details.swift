import KiwiDeskCore
import SwiftUI

/// Secondary cards for Screens settings (#678 Phase 3, turn 13b).
extension ScreensSection {
    /// Card displaying spaces pinned to absent screens (`ScreensGates`).
    @ViewBuilder func orphanCard(
        rows: ScreensFamilyRows,
        gates: ScreensGates
    ) -> some View {
        if gates.inertReason(for: .screens(.orphanPinClear))
            == nil
        {
            SettingsSection(
                SettingsCatalog.screens.orphanPins
            ) {
                ForEach(rows.orphans) { orphan in
                    orphanRow(orphan)
                }
            }
        }
    }

    private func orphanRow(_ orphan: OrphanPin) -> some View {
        // The readout is ONE spoken element, the button a sibling
        // — combining an interactive child folds the clear action
        // into the label. The sentence keeps the space name
        // INSIDE it: a chip beside a prose fragment is a value
        // stitched by an HStack, which no translation can reorder
        // (docs review 2026-08-04).
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.orphanSentence(orphan))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                if orphan.number == nil {
                    Text(orphan.fingerprint)
                        .font(
                            .system(.caption, design: .monospaced)
                        )
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                orphan.number == nil
                    ? L(
                        "monitors.orphan_pin.row_axlabel",
                        "%1$@, waiting for screen %2$@",
                        Self.orphanSentence(orphan),
                        orphan.fingerprint
                    ) : Self.orphanSentence(orphan)
            )
            Spacer()
            Button(backToAutomatic) {
                model.place(orphan.space, .auto)
            }
            .settingsActionButton()
        }
    }

    /// Formatted status sentence for a waiting pin; one whose
    /// screen was left unnumbered names that screen (#3688). Names
    /// no fallback screen, because the runtime does not promise one:
    /// `SpacePlacement.resolve` answers `.pinnedAbsent` with the
    /// positional default's assignment (docs review 2026-08-04).
    /// "Space %1$@" keeps the noun — a bare numeral opening a
    /// sentence is not writable in ja/ko.
    static func orphanSentence(_ orphan: OrphanPin) -> String {
        if let number = orphan.number, let left = orphan.unnumberedScreen {
            return L(
                "monitors.orphan_pin.sentence_unnumbered",
                "Space %1$@ is pinned to Screen %2$d and opens "
                    + "elsewhere for now, because %3$@ isn't numbered "
                    + "this session.",
                orphan.space.raw,
                number,
                left
            )
        }
        if let number = orphan.number {
            return L(
                "monitors.orphan_pin.sentence_numbered",
                "Space %1$@ is pinned to Screen %2$d, which isn't "
                    + "connected, so it opens elsewhere for now.",
                orphan.space.raw,
                number
            )
        }
        let space = orphan.space
        return L(
            "monitors.orphan_pin.sentence",
            "Space %1$@ is pinned to a screen that isn't "
                + "attached, so it opens elsewhere for now.",
            space.raw
        )
    }

    /// Label key for resetting space pin to automatic placement.
    private var backToAutomatic: String {
        L(
            "monitors.clear_pin.label",
            "Back to automatic placement"
        )
    }

    /// Read-only screen hardware identification drawer.
    func fingerprintsDrawer(
        rows: ScreensFamilyRows
    ) -> some View {
        SettingsDisclosure(
            SettingsCatalog.screens.screenFingerprints,
            chrome: .card,
            isExpanded: $advancedExpanded
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(
                    L(
                        "monitors.advanced.caption",
                        "Profiles reattach automatically when "
                            + "a known screen setup is "
                            + "reconnected."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                ForEach(rows.orderedDisplays, id: \.id) {
                    display in
                    fingerprintRow(display)
                }
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Row presenting screen name and fingerprint (#540 rejected
    /// a per-row label as noise). VoiceOver is the case the drawer
    /// title does not cover — rows are stepped one at a time, so
    /// the row spoke a bare hex string: hence one combined element
    /// with an explicit spoken label, no visible change.
    private func fingerprintRow(_ display: Display) -> some View {
        HStack {
            Image(systemName: "display")
                .foregroundStyle(.secondary)
            Text(display.name)
            Spacer()
            Text(display.fingerprint)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            L(
                "monitors.advanced.row_axlabel",
                "%1$@, fingerprint %2$@",
                display.name,
                display.fingerprint
            )
        )
    }
}
