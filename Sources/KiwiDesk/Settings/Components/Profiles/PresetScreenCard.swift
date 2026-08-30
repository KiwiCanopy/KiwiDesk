import KiwiDeskCore
import SwiftUI

/// Preset thumbnail drawing one outline per screen (#678).
///
/// Displays opening layout glyph per screen, with space count underneath.
struct PresetScreenCard: View {
    let layout: StandardLayout
    /// Live screen sizes, or nil when in "For other setups" drawer.
    var liveSizes: [CGSize]?

    /// Screen outline size and layout metrics (#789).
    private static let outline = CGSize(width: 48, height: 30)
    private static let glyphSize: CGFloat = 14
    private static let gap: CGFloat = 4

    /// Maximum slots drawn before "+N" chip (`ProfileScreenPips.slots`).
    private static var slots: Int { ProfileScreenPips.slots }

    private static var moreSize: CGFloat {
        ProfileScreenPips.moreSize
            * (glyphSize / ProfileScreenPips.glyph)
    }

    private var screenCount: Int { max(layout.screenCount, 0) }

    /// Screen outlines drawn before overflow
    /// (`LayoutSchematicCountTests`, #859).
    var shown: Int {
        OverflowSplit.shown(
            of: screenCount,
            fitting: Self.slots,
            withMarker: Self.slots - 1
        )
    }

    var hidden: Int { max(screenCount - shown, 0) }

    private var screens: Range<Int> { 0..<shown }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: Self.gap) {
                ForEach(screens, id: \.self) { screen in
                    outlineView(screen)
                }
                if hidden > 0 { moreChip }
            }
            Text(spaceCountText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Chip displaying count of hidden overflow screens.
    private var moreChip: some View {
        Text(verbatim: "+\(hidden)")
            .font(.system(size: Self.moreSize, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(SettingsTheme.ink3)
            .frame(
                width: Self.outline.width,
                height: Self.outline.height
            )
            .accessibilityHidden(true)
    }

    private var spaceCountText: String {
        spaceCountPhrase(layout.spaceCount)
    }

    private func spaceCountPhrase(_ count: Int) -> String {
        count == 1
            ? L("profiles.spaces.one", "1 Space")
            : L("profiles.spaces.many", "%1$d Spaces", count)
    }

    /// Screen outline view with layout mode glyph and accessibility label.
    private func outlineView(_ screen: Int) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(SettingsTheme.accent.opacity(0.12))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        SettingsTheme.hairline
                    )
            }
            .overlay {
                if let mode = openingMode(screen) {
                    Image(systemName: mode.glyph)
                        .font(.system(size: Self.glyphSize))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(
                width: Self.outline.width,
                height: Self.outline.height
            )
            .help(screenHelp(screen))
            .accessibilityElement()
            .accessibilityLabel(screenHelp(screen))
    }

    /// Shared preview plan derivation (`PresetPreviewPlan`, #859).
    private var plan: PresetPreviewPlan {
        PresetPreviewPlan(layout: layout, liveSizes: liveSizes)
    }

    private func spaceCount(on screen: Int) -> Int {
        plan.group(screen: screen)?.slots.count ?? 0
    }

    private func openingMode(_ screen: Int) -> LayoutMode? {
        plan.group(screen: screen)?.openingMode
    }

    /// Help tooltip and accessibility description for a screen outline.
    private func screenHelp(_ screen: Int) -> String {
        guard let mode = openingMode(screen) else {
            return L(
                "presets.screen_help.empty",
                "%1$@: no Spaces",
                presetScreenName(screen)
            )
        }
        return L(
            "presets.screen_help",
            "%1$@: %2$@, opens in %3$@",
            presetScreenName(screen),
            spaceCountPhrase(spaceCount(on: screen)),
            mode.displayName
        )
    }
}
