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
            Text(card.screen)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: SchematicScale.tile.width)
        // One element, one sentence: three separate labels would
        // be read as three items with no relation between them.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L(
                "onboarding.starter_spaces.tile.axlabel",
                "Space %1$@, %2$@, on %3$@",
                card.id,
                card.mode.displayName,
                card.screen
            )
        )
    }

    private var spacesTitle: String {
        L("onboarding.starter_spaces.title", "Spaces, ready to use")
    }

    /// Names the screens the setup was derived from, which is the
    /// whole claim. `screenNames` comes from the same source the
    /// Monitors area draws, so the two never disagree — and never
    /// says a diagonal, because EDID lies about it.
    private var spacesBody: String {
        let screens = model.screenNames()
        guard !screens.isEmpty else {
            return L(
                "onboarding.starter_spaces.body.generic",
                "Each one arranges windows a different way, "
                    + "chosen for your screen."
            )
        }
        return L(
            "onboarding.starter_spaces.body",
            "Each one arranges windows a different way, chosen "
                + "for: %1$@",
            screens.joined(separator: ", ")
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
