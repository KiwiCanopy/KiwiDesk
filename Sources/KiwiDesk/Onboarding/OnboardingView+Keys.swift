import KiwiDeskCore
import SwiftUI

extension OnboardingView {
    /// The keys step (turn 15a), replacing the page that pointed
    /// at the shortcuts panel and named one chord.
    ///
    /// Five chord families a user reads in four seconds beat a
    /// pointer to a panel — the panel is still one button away,
    /// and the closing card teaches its chord again.
    ///
    /// Shown on every tour since #828: the discovery flag decides
    /// whether an unfinished tour RESUMES here at launch, which
    /// is all #331 ruled, and gating the screen itself on it hid
    /// the shortcuts from everyone who had already finished once
    /// (`OnboardingModel.continueAfterSpaces`).
    var keys: some View {
        OnboardingPage(
            title: keysTitle,
            body1: keysLead,
            hint: L(
                "onboarding.keys.hint",
                "Try one now — nothing will break."
            )
        ) {
            families
        } action: {
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
            .kiwiProminentButton()
            .keyboardShortcut(.defaultAction)
        }
    }

    /// What the list below IS. It states no clash with macOS,
    /// deliberately: the app HAS a conflict detector and this
    /// call site does not ask it, so "none of them clash" was a
    /// claim with no evidence behind it (#678 Phase 4 pass 11).
    ///
    /// About the ROWS, not the set — `families` returns only what
    /// is bound and silently omits the rest, so "all bound
    /// already" asserted completeness over a filtered list.
    private var keysLead: String {
        L(
            "onboarding.keys.body",
            "These are ready to use, on the keyboard you have "
                + "now."
        )
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
            .font(.system(size: 13.5))
            .foregroundStyle(SettingsTheme.ink2)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            // No card around the list (the prototype draws none):
            // a keycap already reads as its own object, and a
            // container around five of them makes the screen a
            // form rather than a reference card.
            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows) { row(for: $0) }
            }
        }
    }

    private func row(
        for family: OnboardingKeyFamily
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(family.label)
                .font(.system(size: 13.5))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            keycap(family)
        }
        // One element per family: the label and the chord are one
        // fact, and read apart they are two items with nothing
        // relating them.
        .accessibilityElement(children: .combine)
    }

    /// A key on a keyboard, drawn as one: the chord in a chip
    /// rather than as loose monospace, which is what makes the
    /// list scannable at a glance.
    ///
    /// The gateway row's chip is FILLED with the accent, with
    /// `accentInk` on it — the one place in this tour the accent
    /// marks something the user is meant to remember rather than
    /// a control they are meant to press. It is not a button:
    /// the panel it names is an overlay that would land on top of
    /// the tour, which is why the step teaches the chord instead
    /// (owner ruling, 2026-08-11, unchanged).
    private func keycap(
        _ family: OnboardingKeyFamily
    ) -> some View {
        Text(family.glyphs)
            .font(.system(size: 12, weight: .semibold).monospaced())
            .foregroundStyle(
                family.isGateway
                    ? SettingsTheme.accentInk
                    : SettingsTheme.ink
            )
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        family.isGateway
                            ? SettingsTheme.accent
                            : SettingsTheme.sunken
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        family.isGateway
                            // The accent's own ink at low alpha:
                            // a filled chip needs an edge or it
                            // dissolves into a light ground, and
                            // a darker shade of the fill is that
                            // edge without coining a second
                            // green (the prototype draws
                            // `#97b84e` under `#aacb5d`).
                            ? SettingsTheme.accentInk.opacity(0.22)
                            : SettingsTheme.ink2.opacity(0.3),
                        // Heavier than a container hairline: a
                        // keycap is a small object on a light
                        // ground, and at `hairline` it read as an
                        // unbordered patch (owner, on device,
                        // 2026-08-12).
                        lineWidth: 1.2
                    )
            )
    }

    private var keysTitle: String {
        L("onboarding.keys.title", "Your shortcuts")
    }
}
