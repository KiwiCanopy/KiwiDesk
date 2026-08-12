import KiwiDeskCore
import SwiftUI

extension OnboardingView {
    /// The step the shipped tour never had (#678 Phase 4 pass 11,
    /// turn 15a): the spaces KiwiDesk just created, drawn with the
    /// REAL `LayoutSchematic` family — so the picture a user meets
    /// on day one is the picture they meet again in Settings.
    ///
    /// The copy says the setup was chosen, not that each screen
    /// chose its own tile — see `spacesBody`, which carries why
    /// the stronger claim is false.
    /// **Two ink tiers, and the second is not decoration** (#828):
    /// the body is what a Space IS, the footnote is how it sits
    /// under the user's Desktops — the one place the tour answers
    /// the question #768's vocabulary split exists to raise. The
    /// lighter ink is what keeps it reading as reassurance rather
    /// than as a second instruction.
    ///
    /// **10 pt gaps, not the 14 every other step uses.** The
    /// window is one fixed 520×430 for all five steps and this is
    /// the only one carrying a schematic strip AND two copy tiers,
    /// so it is the step a locale that expands overflows first.
    /// What gives, in order, if it ever grows again: the `Spacer`,
    /// then this spacing, then the per-tile screen line — never
    /// `SchematicScale.tile`, which is a shared budget with
    /// Settings' own strip, and never the footnote.
    var spaces: some View {
        VStack(spacing: 10) {
            Text(spacesTitle)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(spacesBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(SettingsTheme.ink2)
            spaceStrip
            Spacer()
            Text(spacesFooter)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(SettingsTheme.ink3)
            Button(L("onboarding.continue", "Continue")) {
                model.continueAfterSpaces()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
        }
    }

    /// A horizontal strip, like Settings' own "Choose a layout" —
    /// it scrolls rather than wrapping, so a setup with more
    /// spaces than fit stays one readable row instead of
    /// reflowing into a grid the window has no height for.
    private var spaceStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(model.starterSpaces()) { card in
                    tile(card)
                }
            }
            .padding(.bottom, 4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(spacesTitle)
    }

    private func tile(_ card: OnboardingSpaceCard) -> some View {
        VStack(spacing: 4) {
            LayoutSchematicView(
                mode: card.mode,
                settings: model.tilingSettings(),
                // Three windows: enough for a layout to show what
                // it does with more than a split, and the same
                // count for every tile, so the strip compares
                // layouts rather than arbitrary window counts.
                windows: 3,
                scale: .tile
            )
            Text(card.mode.displayName)
                .font(.caption.weight(.medium))
            // No screen line when the space is on no connected
            // display: the line said "Main screen" in exactly the
            // case the code had failed to determine one.
            if let screen = card.screen {
                Text(screen)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: SchematicScale.tile.width)
        // One element, one sentence: three separate labels would
        // be read as three items with no relation between them.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(axLabel(card))
    }

    /// Two frames rather than one with a withheld argument: a
    /// space on no connected display has no screen to name, and
    /// a frame whose last slot may be empty would leave every
    /// locale ending on a preposition.
    private func axLabel(_ card: OnboardingSpaceCard) -> String {
        guard let screen = card.screen else {
            return L(
                "onboarding.starter_spaces.tile.axlabel.no_screen",
                "Space %1$@, %2$@",
                card.id,
                card.mode.displayName
            )
        }
        return L(
            "onboarding.starter_spaces.tile.axlabel",
            "Space %1$@, %2$@, on %3$@",
            card.id,
            card.mode.displayName,
            screen
        )
    }

    private var spacesTitle: String {
        L("onboarding.starter_spaces.title", "Spaces, ready to use")
    }

    /// One sentence, no interpolation, and no per-screen claim.
    ///
    /// Three separate defects were written into this one string
    /// before it settled, each caught by a localization audit
    /// rather than by any guard — worth listing, because the
    /// sentence looks harmless every time:
    ///
    /// 1. **"Each one uses a DIFFERENT layout"** — false whenever
    ///    the budget forces a repeat, which `StarterAllocation`
    ///    explicitly permits and which is guaranteed past four
    ///    screens. The strip beneath would show the two identical
    ///    tiles disproving it.
    /// 2. **"chosen for: <screens>"** — the list was
    ///    `joined(separator: ", ")` in SWIFT, so no catalog could
    ///    supply `、` for ja/zh-Hant; and it did not say what was
    ///    chosen for what, which three locales independently read
    ///    as a PURPOSE (ja `用途`, ko `용도`, ru `назначение`).
    ///    Three locales patching one frame is how the English
    ///    announces it is the defect.
    /// 3. **"the layout ITS SCREEN suits"** —
    ///    `ScreenClass.layouts` carries no `.floating` at all,
    ///    because where the one Floating space goes is a rule
    ///    about the SETUP rather than a screen's preference. So
    ///    one tile in every setup with room for it is, by design,
    ///    not derived from the screen it sits on. That claim
    ///    became false the day Floating moved out, and all ten
    ///    catalogs had already translated it.
    ///
    /// What survives all three: the SETUP was chosen, each space
    /// has its own layout. The tiles carry the per-space facts,
    /// which a sentence about every screen at once cannot.
    ///
    /// #828 added the first sentence — what a Space is FOR, by
    /// analogy to the thing the user already has — and kept the
    /// second unchanged, defects and all still avoided. It
    /// deliberately did NOT re-add the prototype's list of screen
    /// names: that is defect 2 above, and re-adding it needs a
    /// locale-aware list format rather than a Swift `joined`, so
    /// it is a decision of its own rather than a side effect of
    /// this one. The per-tile screen lines below carry the fact
    /// meanwhile.
    ///
    /// And no count, in any tier: the prototype's "Five spaces to
    /// start" cannot survive a screen-derived seed, and a frame
    /// interpolating a count must put the number last
    /// (`.claude/rules/localization.md`), which no heading can
    /// do. The strip below IS the count.
    private var spacesBody: String {
        L(
            "onboarding.starter_spaces.body",
            "Use these the way you used your Mac's Desktops — "
                + "one keystroke away, but each one arranges its "
                + "windows for you. Each has its own layout, "
                + "chosen for your setup."
        )
    }

    /// The quieter tier, and the load-bearing one: it is the only
    /// place the tour says how the two systems NEST, which is the
    /// question a user who has just been given five Spaces on top
    /// of their Desktops actually has. If this step ever has to
    /// shed a line, it is not this one (#828).
    private var spacesFooter: String {
        L(
            "onboarding.starter_spaces.footer",
            // "any of these SPACES", not "any of this": the only
            // plural noun in the preceding sentence is Desktops,
            // which Settings cannot rename — and pt-BR's
            // translator produced a pronoun agreeing with it.
            "Rename or change any of these Spaces in Settings, "
                + "whenever you want to. Your Mac's own Desktops "
                + "still exist underneath — one of them can hold "
                + "a whole set of these, though you will not "
                + "need that for a long time."
        )
    }
}
