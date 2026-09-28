import KiwiDeskCore
import SwiftUI

/// One seeded Space on the tour's Spaces step: a thumbnail that
/// plays its layout's story (#1750), its name and where it lives.
/// The row plays once on first appearance, `delay` after the
/// page, and again each time the pointer enters it.
struct OnboardingSpaceRow: View {
    let card: OnboardingSpaceCard
    let settings: TilingSettings
    let delay: Double
    @State private var replay = 0

    private static let thumbHeight: CGFloat = 46
    private static var thumbFactor: CGFloat {
        thumbHeight / SchematicScale.tile.height
    }
    private static var thumbWidth: CGFloat {
        (SchematicScale.tile.width ?? 0) * thumbFactor
    }

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    L(
                        "onboarding.starter_spaces.row.name",
                        "Space %1$@",
                        card.id
                    )
                )
                .font(.system(size: 13.5, weight: .semibold))
                Text(detail)
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
        .contentShape(Rectangle())
        .onHover { inside in if inside { replay += 1 } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(axLabel)
        .accessibilityValue(OnboardingLayoutBehaviour.of(card.mode))
    }

    /// Miniature layout schematic for the space card (#786).
    private var thumbnail: some View {
        LayoutStoryThumbnail(
            mode: card.mode,
            settings: settings,
            scale: .tile,
            delay: delay,
            replay: replay
        )
        .scaleEffect(Self.thumbFactor)
        .frame(width: Self.thumbWidth, height: Self.thumbHeight)
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(SettingsTheme.previewPlate)
        )
        .environment(
            \.schematicPalette,
            HomeCardPlate.palette(settings)
        )
    }

    private var detail: String {
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

    private var axLabel: String {
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
}
