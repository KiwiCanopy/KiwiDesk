import KiwiDeskCore
import SwiftUI

/// The per-row layout-mode picker and the live-vs-saved drift
/// caption (#123), split from `SpacesSection` for file size.
extension SpacesSection {
    func modePicker(_ space: SpaceID) -> some View {
        // Hoisted out of the modifier chain (§5 type-checker
        // budget); doubles as the accessibility label since
        // the visible label is hidden.
        let modeHint = L(
            "spaces.mode.help",
            "Layout mode for this Space"
        )
        return VStack(alignment: .trailing, spacing: 4) {
            Picker("", selection: modeBinding(space)) {
                ForEach(LayoutMode.allCases, id: \.self) { mode in
                    Label(
                        mode.displayName,
                        systemImage: mode.glyph
                    )
                    .tag(mode)
                }
            }
            .labelsHidden()
            .controlSize(.large)
            .frame(width: 150)
            // Label is hidden, so the picker's purpose is
            // inferable only from its options — a one-line
            // hover hint names it (#94).
            .help(modeHint)
            .accessibilityLabel(modeHint)
            // A label REPLACES what the picker announced, the
            // selected mode included; the value puts it back
            // (#812 — "pop up button" with no mode spoken).
            .accessibilityValue(
                modeBinding(space).wrappedValue.displayName
            )
            // The row's focus representative (#678 Phase 4 pass
            // 10, turn 20a rule 4): where a deletion lands, and
            // where leaving the pushed override editor returns.
            //
            // This picker rather than the Overrides button that
            // actually opened the editor, because that button is
            // MODE-GATED (`SpaceOverrideOffer.isOffered`) and an
            // absent preference means Simple — so on a fresh
            // install it is not drawn at all, and a focus
            // assigned to a value no view claims goes to the top
            // of the list, which is the behaviour this rule
            // exists to prevent (code review, 2026-08-11; the
            // first cut bound the gated button and its guard,
            // being a source needle, stayed green). Resetting
            // the last override retires the offer mid-editor
            // too, so even the return path cannot rely on it.
            //
            // A picker is also the benign choice among the row's
            // always-drawn controls: the name field would open an
            // edit and the delete button would put a destructive
            // action under the next keypress.
            .focused($returningRow, equals: space)

            // The one drift source (`model.layoutDrift`), shared
            // with the footer captions — never a second inline
            // comparison, and no profile read in the render path.
            if space == model.core.activeSpace?.id,
                let drift = model.layoutDrift
            {
                Text(
                    L(
                        "settings.layout.drift",
                        "Live: %1$@ — profile has %2$@ (not saved)",
                        drift.live.displayName,
                        drift.saved.displayName
                    )
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    /// Setting a space to the default `bsp` removes its entry
    /// (the writer treats absent as `bsp`).
    func modeBinding(
        _ space: SpaceID
    ) -> Binding<LayoutMode> {
        Binding(
            get: { model.config.spaceModes[space] ?? .bsp },
            set: { mode in
                model.config.spaceModes[space] =
                    mode == .bsp ? nil : mode
            }
        )
    }
}
