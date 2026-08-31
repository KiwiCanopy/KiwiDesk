import KiwiDeskCore
import SwiftUI

/// Space layout mode picker and live drift indicator (`SpacesSection`, #123).
extension SpacesSection {
    func modePicker(_ space: SpaceID) -> some View {
        // Hoisted (§5 type-checker budget); doubles as the
        // accessibility label since the visible label is hidden —
        // the one-line hover hint names the picker (#94).
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
            .help(modeHint)
            .accessibilityLabel(modeHint)
            // A label REPLACES what the picker announced, the
            // selected mode included; the value puts it back
            // (#812 — "pop up button" with no mode spoken).
            .accessibilityValue(
                modeBinding(space).wrappedValue.displayName
            )
            // The row's focus representative (#678 Phase 4 turn
            // 20a rule 4). This picker, NOT the Overrides button
            // that opened the editor: that button is MODE-GATED
            // (`SpaceOverrideOffer.isOffered`) and absent on a
            // fresh install — a focus assigned to a value no view
            // claims goes to the top of the list (code review
            // 2026-08-11). A picker is also the benign choice:
            // the name field opens an edit, delete is
            // destructive.
            .focused($returningRow, equals: space)

            // The one drift source (`model.layoutDrift`), shared
            // with the footer captions — never a second inline
            // comparison, no profile read in the render path.
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

    /// Binding for space layout mode omitting default bsp value.
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
