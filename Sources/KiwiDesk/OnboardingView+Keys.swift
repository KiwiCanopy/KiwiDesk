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
            Text(
                L(
                    "onboarding.keys.body",
                    "All bound already, and none of them clash "
                        + "with macOS. Try one now — nothing will "
                        + "break."
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
            Text(
                L(
                    "onboarding.keys.none",
                    "Your shortcuts are yours to set — the panel "
                        + "below lists everything that is bound."
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
