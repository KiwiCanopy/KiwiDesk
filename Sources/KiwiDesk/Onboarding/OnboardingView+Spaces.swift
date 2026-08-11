import KiwiDeskCore
import SwiftUI

extension OnboardingView {
    /// The step the shipped tour never had (#678 Phase 4 pass 11,
    /// turn 15a): the spaces KiwiDesk just created, drawn with the
    /// REAL `LayoutSchematic` family — so the picture a user meets
    /// on day one is the picture they meet again in Settings.
    ///
    /// The copy claims the spaces were chosen for these screens,
    /// and since pass 11 that is true: `ScreenClass` picks each
    /// screen's layouts from its shape. Against the retired ladder
    /// — five per display, the same five everywhere — the same
    /// sentence was a preview claiming engine behavior the engine
    /// did not have.
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

    /// One sentence, no interpolation.
    ///
    /// It used to say "Each one uses a different layout, chosen
    /// for: <screens>", and that was wrong three ways at once
    /// (localization audit, 2026-08-11):
    ///
    /// - **"different" is false whenever the budget forces a
    ///   repeat**, which `StarterAllocation` explicitly permits
    ///   and which is guaranteed at four or more screens — and
    ///   the strip drawn directly beneath would show the two
    ///   identical tiles disproving it;
    /// - the screen list was `joined(separator: ", ")` in SWIFT,
    ///   before the frame, so no catalog could supply `、` for
    ///   ja/zh-Hant and no locale could drop the ASCII space;
    /// - "chosen for: <list>" did not say what was chosen for
    ///   what, and three locales independently read it as a
    ///   PURPOSE — ja `用途`, ko `용도`, ru `назначение`.
    ///   Three locales patching one frame is how the English
    ///   announces it is the defect.
    ///
    /// Each tile already prints its own screen under its own
    /// layout, attributed per space, which a sentence naming all
    /// the screens at once cannot do — it implies every layout
    /// was chosen for every screen. So the sentence states the
    /// rule and the tiles carry the facts.
    private var spacesBody: String {
        L(
            "onboarding.starter_spaces.body",
            "Each one has the layout its screen suits."
        )
    }

    private var spacesFooter: String {
        L(
            "onboarding.starter_spaces.footer",
            "Your Mac's own Desktops still exist underneath. "
                + "Rename or change any of this in Settings, "
                + "whenever you want to."
        )
    }
}
