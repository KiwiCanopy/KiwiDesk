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
    /// than as a second instruction. `OnboardingPage` owns both
    /// tiers, so every step draws them the same size.
    var spaces: some View {
        OnboardingPage(
            title: spacesTitle,
            body1: spacesBody,
            footnote: spacesFooter,
            // The pictures are what this screen is FOR, so the
            // Desktop↔Space nesting waits below them rather than
            // standing between the reader and the grid.
            footnoteAtBottom: true,
            hint: L(
                "onboarding.starter_spaces.hint",
                "More Spaces or other layouts? Settings, "
                    + "whenever you want them."
            )
        ) {
            spaceStrip
        } action: {
            Button(L("onboarding.continue", "Continue")) {
                model.continueAfterSpaces()
            }
            .kiwiProminentButton()
            .keyboardShortcut(.defaultAction)
        }
    }

    /// One space per ROW, as the prototype draws them (owner
    /// ruled 2026-08-12, revising the three-per-row grid after
    /// seeing it): picture on the left, the space's name and what
    /// it is beside it. A grid of pictures compares layouts; this
    /// screen is not asking the user to choose one, it is telling
    /// them what they already have — and a row can carry the name
    /// and the screen the tile had nowhere to put.
    ///
    /// Scrolls past what fits, which is what makes it safe on the
    /// setup that stresses it: three monitors seed eight spaces or
    /// more.
    private var spaceStrip: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                ForEach(model.starterSpaces()) { card in
                    row(card)
                }
            }
            .padding(.bottom, 2)
        }
        // Tall enough for three rows and a hint of the fourth —
        // an edge cut mid-row is what says "there is more" on a
        // list with no scrollbar showing. A bare `ScrollView` in
        // a `VStack` takes all the space there is, which would
        // push the footer off a screen holding two.
        .frame(maxHeight: 232)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(spacesTitle)
    }

    /// The row's thumbnail height, and with it the factor the
    /// schematic is drawn at.
    ///
    /// A scale FACTOR, never a third `SchematicScale` case — the
    /// shape `HomeCardSchematicBand` already uses to put a `.tile`
    /// schematic in a plate band. The geometry, the captions and
    /// the what-a-thumbnail-omits rulings stay one definition.
    private var thumbHeight: CGFloat { 46 }
    private var thumbFactor: CGFloat {
        thumbHeight / SchematicScale.tile.height
    }
    /// Derived from the scale, never a second copy of its 132:
    /// a retune of the tile width would otherwise leave this row
    /// drawing at the old one. `.tile`'s width is non-nil by
    /// construction — `.panel` is the scale that fills its pane —
    /// and a zero here would draw nothing rather than something
    /// wrong.
    private var thumbWidth: CGFloat {
        (SchematicScale.tile.width ?? 0) * thumbFactor
    }

    private func row(_ card: OnboardingSpaceCard) -> some View {
        HStack(spacing: 12) {
            thumbnail(card)
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    L(
                        "onboarding.starter_spaces.row.name",
                        "Space %1$@",
                        card.id
                    )
                )
                .font(.system(size: 13.5, weight: .semibold))
                Text(rowDetail(card))
                    .font(.system(size: 11.5))
                    .foregroundStyle(SettingsTheme.ink3)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(SettingsTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(SettingsTheme.hairline, lineWidth: 1)
        )
        // One element, one sentence: three separate labels would
        // be read as three items with no relation between them.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(axLabel(card))
    }

    /// The picture rides the desktop plate, in the user's own
    /// palette — the same construction Home's profile cards use
    /// (#786), through `HomeCardPlate.palette` rather than a
    /// second fold beside it: a user colour that sinks into the
    /// fixed dark ground swaps for a theme fallback there, and a
    /// copy here would be a second place for that floor to drift.
    private func thumbnail(_ card: OnboardingSpaceCard) -> some View {
        LayoutSchematicView(
            mode: card.mode,
            settings: model.tilingSettings(),
            // Three windows: enough for a layout to show what it
            // does with more than a split, and the same count for
            // every row, so the strip compares layouts rather than
            // arbitrary window counts.
            windows: 3,
            scale: .tile
        )
        .scaleEffect(thumbFactor)
        .frame(width: thumbWidth, height: thumbHeight)
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(SettingsTheme.previewPlate)
        )
        .environment(
            \.schematicPalette,
            HomeCardPlate.palette(model.tilingSettings())
        )
    }

    /// The layout and the screen, in ONE frame — never joined in
    /// Swift. A separator written here is one no catalog could
    /// change, and `、` is what ja and zh-Hant need where English
    /// writes `·`.
    private func rowDetail(_ card: OnboardingSpaceCard) -> String {
        guard let screen = card.screen else {
            return card.mode.displayName
        }
        return L(
            "onboarding.starter_spaces.row.detail",
            "%1$@ · %2$@",
            card.mode.displayName,
            screen
        )
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

    /// A sentence, not a label.
    ///
    /// "Spaces, ready to use" is an English noun phrase that only
    /// works in English — German renders it "Spaces,
    /// einsatzbereit", which reads like a status line on a piece
    /// of equipment (owner, 2026-08-12). A subject-verb heading
    /// translates into every locale this app ships, and it says
    /// the same thing: the setup is done and it is theirs.
    private var spacesTitle: String {
        L(
            "onboarding.starter_spaces.title",
            "Your Spaces are ready"
        )
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
