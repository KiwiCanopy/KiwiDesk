import KiwiDeskCore
import SwiftUI

extension OnboardingView {
    /// Tour screen presenting the seeded spaces (#678, #768, #828).
    var spaces: some View {
        OnboardingPage(
            title: spacesTitle,
            body1: spacesBody,
            footnote: spacesFooter,
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

    /// Vertical list of space cards with layout schematic thumbnails.
    private var spaceStrip: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                ForEach(model.starterSpaces()) { card in
                    row(card)
                }
            }
            .padding(.bottom, 2)
        }
        .frame(maxHeight: 232)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(spacesTitle)
    }

    private var thumbHeight: CGFloat { 46 }
    private var thumbFactor: CGFloat {
        thumbHeight / SchematicScale.tile.height
    }
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(axLabel(card))
    }

    /// Miniature layout schematic for the space card (#786).
    private func thumbnail(_ card: OnboardingSpaceCard) -> some View {
        LayoutSchematicView(
            mode: card.mode,
            settings: model.tilingSettings(),
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
        L(
            "onboarding.starter_spaces.title",
            "Your Spaces are ready"
        )
    }

    /// Explanatory body describing starter spaces and layout assignments
    /// (#828).
    private var spacesBody: String {
        L(
            "onboarding.starter_spaces.body",
            "Use these the way you used your Mac's Desktops — "
                + "one keystroke away, but each one arranges its "
                + "windows for you. Each has its own layout, "
                + "chosen for your setup."
        )
    }

    /// Explains how Spaces relate to native macOS Desktops (#828).
    private var spacesFooter: String {
        L(
            "onboarding.starter_spaces.footer",
            "Rename or change any of these Spaces in Settings, "
                + "whenever you want to. Your Mac's own Desktops "
                + "still exist underneath — one of them can hold "
                + "a whole set of these, though you will not "
                + "need that for a long time."
        )
    }
}
