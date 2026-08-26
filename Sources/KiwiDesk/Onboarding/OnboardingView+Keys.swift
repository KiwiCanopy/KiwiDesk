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
        let rows = model.keyFamilies()
        return OnboardingPage(
            title: keysTitle,
            body1: keysLead,
            // Under the body rather than at the bottom: it is the
            // RULE the six rows below are instances of, and a
            // reader who meets it first reads the list as one
            // scheme instead of five chords. At the bottom it
            // would also sit directly above the footer hint, two
            // quiet greys deep.
            footnote: OnboardingKeys.tierAnchor(rows),
            hint: L(
                "onboarding.keys.hint",
                "Try one now — nothing will break."
            )
        ) {
            families(rows)
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
            // The PHYSICAL keyboard, said so: "the keyboard you
            // have now" also reads as the app's keyboard-layout
            // model, which this sentence says nothing about.
            "These are ready to use, on the keyboard you are "
                + "typing on."
        )
    }

    @ViewBuilder private func families(
        _ rows: [OnboardingKeyFamily]
    ) -> some View {
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
            // container around six of them makes the screen a
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

    /// The chord, drawn as the keys it is: one chip per
    /// modifier with the word printed on that key under it, `+`
    /// between them, then the keys that differ (#1016).
    ///
    /// Before this it was one chip reading `⌃⌥ ← ↓ ↑ →`, which
    /// taught a chord to everyone who could already decode
    /// `⌃ ⌥ ⇧` and nothing at all to the reader this step is
    /// for. Separating the caps is what makes it three keys
    /// rather than one symbol, and the legend is what lets them
    /// find each one.
    ///
    /// **The `+` is drawn BETWEEN chips, never inside one.**
    /// `ComboSymbols` drops the separator precisely so that a
    /// `+` inside a chord is the KEY (`⌃⌥+` on a German layout,
    /// #23), and that stays true here — a chip boundary is what
    /// separates two keys, so the loose `+` cannot be mistaken
    /// for one.
    ///
    /// The gateway row's chips are FILLED with the accent, with
    /// `accentInk` on them — the one place in this tour the
    /// accent marks something the user is meant to remember
    /// rather than a control they are meant to press. It is not
    /// a button: the panel it names is an overlay that would
    /// land on top of the tour, which is why the step teaches
    /// the chord instead (owner ruling, 2026-08-11, unchanged).
    @ViewBuilder private func keycap(
        _ family: OnboardingKeyFamily
    ) -> some View {
        // `.top`, so the glyph line stays level across chips
        // whose legends wrap differently — a legend hangs BELOW
        // its glyph and must not push the glyph down.
        HStack(alignment: .top, spacing: 5) {
            switch family.chord {
            case .shared(let modifiers, let keys):
                ForEach(
                    OnboardingModifierNames.named(modifiers)
                ) { modifier in
                    namedChip(modifier, family: family)
                    plus
                }
                chip(keys, family: family)
            case .mixed(let text):
                // Nothing shared to name: each chord is written
                // in full, which is the honest rendering of a
                // keymap edited apart (`OnboardingChord`).
                chip(text, family: family)
            }
        }
        // **The chord speaks as ONE thing, from the model the
        // chips are drawn from.** Combined, VoiceOver read the
        // chips as written — every `+` separator as the word
        // "plus", and a name under each cap — which is a
        // rendering detail spoken aloud. `glyphs` is the same
        // chord `ComboSymbols` writes everywhere else in the app,
        // and taking it from the model rather than from a second
        // string is what stops the drawn and the spoken chord
        // disagreeing: the one failure a step that exists to
        // teach a chord cannot afford.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(family.glyphs)
    }

    /// One modifier: its glyph in a chip, the key's name under
    /// it.
    private func namedChip(
        _ modifier: OnboardingModifierName,
        family: OnboardingKeyFamily
    ) -> some View {
        VStack(spacing: 3) {
            chip(modifier.glyph, family: family)
            Text(modifier.name)
                .font(.system(size: 9.5))
                .foregroundStyle(SettingsTheme.ink3)
                // Silent. Each row is ONE accessibility element,
                // and VoiceOver already reads `⌃` as "control" —
                // announced, the name would say every modifier
                // of every chord twice (#1016).
                .accessibilityHidden(true)
        }
        .fixedSize()
    }

    /// The combinator between two keys. Padded like a chip's own
    /// text so it sits on the glyph line rather than at the top
    /// edge the `.top` alignment measures from.
    private var plus: some View {
        Text(verbatim: "+")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(SettingsTheme.ink3)
            .padding(.vertical, 4)
    }

    /// A key on a keyboard, drawn as one: a chip rather than
    /// loose monospace, which is what makes the list scannable
    /// at a glance.
    private func chip(
        _ text: String,
        family: OnboardingKeyFamily
    ) -> some View {
        Text(text)
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
