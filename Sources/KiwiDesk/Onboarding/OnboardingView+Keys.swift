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
            families
            Spacer()
            // No "View Shortcuts…" button (owner ruling,
            // 2026-08-11, on the device): the panel it opens is
            // an OVERLAY, so it lands on top of the tour and
            // competes with the very list this step already
            // draws. The step teaches the chords; the panel is
            // for later, and the closing card says where the app
            // lives. Re-adding it needs the overlay problem
            // solved first, not just a second opinion on the
            // button.
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
            // Names no control, because this step now has only
            // a Continue button. It said "the panel below" while
            // the panel opened elsewhere, then "the button
            // below" until that button was removed — a sentence
            // pointing at chrome is a sentence that has to be
            // re-checked every time the chrome moves.
            Text(
                L(
                    "onboarding.keys.none",
                    "Your shortcuts are yours to set, and none "
                        + "are bound yet. Settings has the full "
                        + "list whenever you want it."
                )
            )
            .font(.callout)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
        } else {
            // The reassurance lives HERE, not above the branch:
            // drawn unconditionally it stood two lines above the
            // empty state and the screen said "All bound
            // already" and "none are bound yet" at once
            // (localization audit, 2026-08-11). A sentence about
            // the chords belongs where the chords are.
            //
            // States no clash with macOS, deliberately. The app
            // HAS a conflict detector and this call site does not
            // ask it, so "none of them clash" was a claim with no
            // evidence behind it (#678 Phase 4 pass 11).
            Text(
                L(
                    "onboarding.keys.body",
                    "All bound already. Try one now — nothing "
                        + "will break."
                )
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
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
        L("onboarding.keys.title", "Your shortcuts")
    }
}
