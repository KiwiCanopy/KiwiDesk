import KiwiDeskCore
import SwiftUI

/// A look card's picture (#1684): the shelf preview drawn over the
/// draft with the look applied — the user's own Spaces and bars —
/// and a focused window wearing the ring the look's palette
/// colours, its sheen included: the owner ruled the card draws it
/// (2026-09-28), unlike the palette thumbnail, which leaves it undrawn
/// at tile scale (gui.md ▸ #753) — so the ring is drawn wide enough
/// for the ramp to read.
struct LookPlate: View {
    /// The draft with the look painted on.
    let settings: TilingSettings
    let spaceLabels: [SpaceGlyph]

    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: PaletteSceneThumbnail.plateRadius
            )
            .fill(SettingsTheme.sunken)
            HomeCardBarsTile(
                settings: settings,
                spaceCount: spaceLabels.count,
                spaceLabels: spaceLabels,
                wellContent: AnyView(focusedWindow)
            )
            .padding(4)
            .environment(
                \.schematicPalette,
                HomeCardPlate.palette(settings)
            )
        }
        .frame(height: PaletteSceneThumbnail.baseHeight)
        .frame(maxWidth: .infinity)
        // Hidden from VoiceOver, never from the pointer: the plate is
        // most of a card's Button label, so a click on it is the click.
        .accessibilityHidden(true)
    }

    /// A window in the desktop's well, ringed in the focus colour
    /// at the look's width and corners (#1739). Sized off the well,
    /// never the plate, so a narrow card's window never covers the
    /// shelf.
    private var focusedWindow: some View {
        GeometryReader { well in
            let width = well.size.width * Self.windowShare
            let unit = width / Self.referenceWidth
            let shape = RoundedRectangle(cornerRadius: ringRadius * unit)
            shape
                .fill(SettingsTheme.hairline)
                .overlay(
                    shape.stroke(
                        SheenPaint.style(
                            settings.borderStyle.focusedColor,
                            sheen: settings.borderStyle.sheen
                        ),
                        lineWidth: max(1, ringWidth * unit)
                    )
                )
                .frame(
                    width: width,
                    height: well.size.height * Self.windowShare
                )
                .position(x: well.size.width / 2, y: well.size.height / 2)
        }
    }

    /// The window's share of the well on each axis.
    private static let windowShare: CGFloat = 0.6

    /// The window width the ring and corner below are tuned at.
    private static let referenceWidth: CGFloat = 40

    /// The ring's width at the reference window, floored so a thin
    /// ring still reads and capped so the widest leaves the window
    /// visible; the default 5 pt draws 3.
    private var ringWidth: CGFloat {
        min(4, max(1, settings.borderStyle.clampedWidth * 0.6))
    }

    private var ringRadius: CGFloat {
        settings.borderStyle.cornerStyle == .square ? 0 : 4
    }
}
