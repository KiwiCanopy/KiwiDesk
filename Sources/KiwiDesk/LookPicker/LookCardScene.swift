import KiwiDeskCore
import SwiftUI

/// A look's desk on the picker's card (#3038 ▸ Ruling 2026-11-23):
/// three tiled windows at the look's gaps, rings and colours, and the
/// look's bars at its own edges with the profile's Spaces and generic
/// app symbols, over the look's ground. `scale` is the card's size
/// against the screen it shows. Decorative to VoiceOver: the card's
/// element speaks for it.
struct LookCardScene: View {
    let settings: TilingSettings
    let spaceLabels: [SpaceGlyph]
    let scale: CGFloat
    /// The ground's haze reach, the card's height.
    let height: CGFloat

    var body: some View {
        ZStack {
            LookGround(settings: settings, reach: height * 0.9)
            HomeCardBarsTile(
                settings: settings,
                pocketStands: false,
                spaceCount: spaceLabels.count,
                scale: scale * Self.barScale,
                spaceLabels: spaceLabels,
                wellContent: AnyView(
                    LookCardWindows(settings: settings, scale: scale)
                ),
                appArt: nil,
                drawsChrome: false
            )
            .environment(
                \.schematicPalette,
                HomeCardPlate.darkPalette(settings)
            )
        }
        .accessibilityHidden(true)
    }

    /// Schematic points per card point: the bars tile draws a live
    /// point at half a schematic one (`indicatorPerPoint`).
    static let barScale: CGFloat = 2
}

/// The card's three windows: a terminal on the left, Settings above
/// a note on the right, the terminal focused in the look's ring.
/// Gaps and widths are the look's real points at the card's scale.
struct LookCardWindows: View {
    let settings: TilingSettings
    let scale: CGFloat

    var body: some View {
        let gaps = settings.gapsGlobal
        let inner = gaps.inner.horizontal * scale
        GeometryReader { well in
            let side = max(0, (well.size.width - inner) * 0.42)
            HStack(spacing: inner) {
                window(LookPickerText.terminalTitle, dark: true, focused: true)
                VStack(spacing: gaps.inner.vertical * scale) {
                    window(LookPickerText.settingsTitle)
                    window(LookPickerText.noteTitle)
                }
                .frame(width: side)
            }
        }
        .padding(.leading, gaps.outer.left * scale)
        .padding(.trailing, gaps.outer.right * scale)
        .padding(.top, gaps.outer.top * scale)
        .padding(.bottom, gaps.outer.bottom * scale)
    }

    /// The window keeps macOS's rounded corners; a square look
    /// squares only its ring (#3038 ▸ Ruling, Corners).
    private var windowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Self.windowRadius * scale)
    }

    private var ringShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: settings.borderStyle.cornerStyle == .square
                ? 0 : Self.windowRadius * scale
        )
    }

    private var ringWidth: CGFloat {
        max(1, settings.borderStyle.clampedWidth * scale)
    }

    private func window(
        _ title: String,
        dark: Bool = false,
        focused: Bool = false
    ) -> some View {
        let border = settings.borderStyle
        return VStack(spacing: 0) {
            titleBar(title)
            LookCardBody(dark: dark, scale: scale)
        }
        .clipShape(windowShape)
        .padding(ringWidth)
        .overlay {
            if focused, border.enabled {
                ringShape.strokeBorder(
                    SheenPaint.style(border.focusedColor, sheen: border.sheen),
                    lineWidth: ringWidth
                )
            } else if !focused, border.unfocusedEnabled {
                ringShape.strokeBorder(
                    Color(kiwiHex: border.unfocusedColor),
                    lineWidth: ringWidth
                )
            }
        }
    }

    private func titleBar(_ title: String) -> some View {
        Text(title)
            .font(.system(size: titleSize, weight: .medium))
            .foregroundStyle(SettingsTheme.lookGround)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: titleSize * 2.1)
            .background(SettingsTheme.lookWindowLine)
    }

    /// Readable at the card's size, never larger than a real title.
    private var titleSize: CGFloat { min(13, max(10, 13 * scale * 1.4)) }

    static let windowRadius: CGFloat = 10
}

/// A window's body: placeholder lines, no words to translate — dark
/// for the terminal, light paper otherwise.
private struct LookCardBody: View {
    let dark: Bool
    let scale: CGFloat

    var body: some View {
        GeometryReader { box in
            let unit = max(3, 9 * scale)
            VStack(alignment: .leading, spacing: unit * 0.8) {
                ForEach(Array(Self.shares.enumerated()), id: \.offset) {
                    line(unit, share: $0.element)
                }
            }
            .padding(unit * 1.4)
            .frame(
                width: box.size.width,
                height: box.size.height,
                alignment: .topLeading
            )
        }
        .background(dark ? SettingsTheme.lookGround : SettingsTheme.lookWindow)
    }

    private func line(_ unit: CGFloat, share: CGFloat) -> some View {
        Capsule()
            .fill(SettingsTheme.lookWindowLine.opacity(dark ? 0.45 : 1))
            .frame(height: unit * 0.7)
            .scaleEffect(x: share, anchor: .leading)
    }

    private static let shares: [CGFloat] = [0.7, 1, 0.55, 0.8, 0.4]
}
