import KiwiDeskCore
import SwiftUI

/// A look's ground (#1740): its own shelf colour over a night,
/// darkened a step, a faint haze of the focus colour from the top.
/// The look tile draws it, and the look picker draws it as the
/// backdrop of a look with no picture (#3038).
struct LookGround: View {
    let settings: TilingSettings
    /// How far down the focus haze reaches.
    let reach: CGFloat
    var stage: Stage = .plate

    /// Where the ground draws: a tile or card, or the look picker's
    /// full-screen backdrop, which takes no veil and a stronger haze
    /// (owner, prototype 2026-11-26).
    enum Stage {
        case plate, backdrop
    }

    var body: some View {
        ZStack {
            SettingsTheme.lookGround
            Color(kiwiHex: settings.kiwishelf.fillColor)
                .opacity(Self.share(settings))
            if stage == .plate {
                SettingsTheme.lookGround.opacity(0.15)
            }
            RadialGradient(
                colors: [
                    Color(kiwiHex: settings.borderStyle.focusedColor)
                        .opacity(stage == .plate ? 0.3 : Self.backdropHaze),
                    .clear,
                ],
                center: .top,
                startRadius: 0,
                endRadius: reach
            )
        }
    }

    /// How much of the shelf colour the ground takes: whole, save a
    /// light colour, which only tints the night — laid whole it greys
    /// the desk into the windows and the light bar no longer stands
    /// out (Classic, #3494).
    static func share(_ settings: TilingSettings) -> Double {
        let luminance = ColorVision.luminance(settings.kiwishelf.fillColor)
        return (luminance ?? 0) > lightGround ? lightTint : 1
    }

    /// The backdrop's haze, the focus colour's share at the top.
    static let backdropHaze = 0.9

    /// The WCAG luminance above which a shelf colour is light.
    static let lightGround = 0.5
    /// The share of a light shelf colour the ground takes.
    static let lightTint = 0.25
}
