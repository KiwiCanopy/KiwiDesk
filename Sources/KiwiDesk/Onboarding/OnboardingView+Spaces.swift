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
    var spaces: some View {
        VStack(spacing: 14) {
            Text(spacesTitle)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(spacesBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            spaceStrip
            Spacer()
            Text(spacesFooter)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(L("onboarding.continue", "Continue")) {
                model.continueAfterSpaces()
            }
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
    private var spacesBody: String {
        L(
            "onboarding.starter_spaces.body",
            "Each one has its own layout, chosen for your setup."
        )
    }

    private var spacesFooter: String {
        L(
            "onboarding.starter_spaces.footer",
            // "any of these SPACES", not "any of this": the only
            // plural noun in the preceding sentence is Desktops,
            // which Settings cannot rename — and pt-BR's
            // translator produced a pronoun agreeing with it.
            "Your Mac's own Desktops still exist underneath. "
                + "Rename or change any of these Spaces in "
                + "Settings, whenever you want to."
        )
    }
}
