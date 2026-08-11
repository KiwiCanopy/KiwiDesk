import KiwiDeskCore
import SwiftUI

extension OnboardingView {
    /// The keys step (turn 15a), replacing the page that pointed
    /// at the shortcuts panel and named one chord.
    ///
    /// Five chord families a user reads in four seconds beat a
    /// pointer to a panel — the panel is still one button away,
    /// and the closing card teaches its chord again. What did
    /// NOT change is the `wantsDiscovery()` gate: that is a
    /// settled #331 ruling so a resumed run never re-pitches.
    /// The content changed, not the gate.
    var keys: some View {
        VStack(spacing: 14) {
            Text(keysTitle)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            // States no clash with macOS, deliberately. The app
            // HAS a conflict detector and this call site does not
            // ask it, so "none of them clash" was a claim with no
            // evidence behind it — false for anyone who had
            // rebound a system shortcut, and confidently so
            // (#678 Phase 4 pass 11; the pass 9/10 rule that a
            // cause the GUI states must be evidence the code
            // actually has). Real clashes surface in Settings,
            // where the detector is consulted.
            Text(
                L(
                    "onboarding.keys.body",
                    "All bound already. Try one now — nothing "
                        + "will break."
                )
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            families
            Spacer()
            Button(L("menu.view_shortcuts", "View Shortcuts…")) {
                model.onShowShortcuts()
            }
            .controlSize(.large)
            Button(L("onboarding.continue", "Continue")) {
                model.continueAfterKeys()
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
        }
    }

    @ViewBuilder private var families: some View {
        let rows = model.keyFamilies()
        if rows.isEmpty {
            // Every chord is looked up, so a keymap with none of
            // these bound draws no rows at all. Say why, rather
            // than leaving a gap where a table was.
            // "The BUTTON below", not "the panel below": the
            // panel opens elsewhere, and what sits below this
            // sentence is the button that opens it. A sentence
            // describing a screen the reader is not looking at
            // is the same defect as one contradicting a tile
            // beside it.
            Text(
                L(
                    "onboarding.keys.none",
                    "Your shortcuts are yours to set — the button "
                        + "below opens the full list."
                )
            )
            .font(.callout)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows) { row(for: $0) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(
        for family: OnboardingKeyFamily
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(family.label)
            Spacer(minLength: 12)
            Text(family.glyphs)
                .font(.body.monospaced())
        }
        // One element per family: the label and the chord are one
        // fact, and read apart they are two items with nothing
        // relating them.
        .accessibilityElement(children: .combine)
    }

    private var keysTitle: String {
        L("onboarding.keys.title", "Your keys")
    }
}
