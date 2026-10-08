import SwiftUI
import Testing

@testable import KiwiDesk

/// The chip tiers' pairings (#2047), measured by the one contrast
/// suite and kept here for their length: each tier's ink over the
/// fills it layers on the grounds it is drawn on. The fills are
/// per-appearance tokens, so they are layered at the alpha each
/// resolves to.
extension SettingsThemeContrastTests {
    /// A segmented control's unselected label over its track, and
    /// over the hover lift above it, on every ground a picker
    /// stands on — the update window's tab strip on the page.
    private static let segments: [Pairing] =
        [
            ("card", SettingsTheme.card),
            ("sunken", SettingsTheme.sunken),
            ("page", SettingsTheme.page),
        ].flatMap { name, ground in
            [
                Pairing(
                    "ink on a segmented track on \(name)",
                    SettingsTheme.ink,
                    on: ground,
                    layers: [SettingsTheme.trackFill]
                ),
                Pairing(
                    "ink on a hovered segment on \(name)",
                    SettingsTheme.ink,
                    on: ground,
                    layers: [
                        SettingsTheme.trackFill,
                        SettingsTheme.chipRest,
                    ]
                ),
            ]
        }

    /// A text button chip's label at rest and under the pointer —
    /// a monitor card's `+n` on `sunken`, the tray's and the
    /// collapsed screen-setups chip's on `card`.
    private static let buttonChips: [Pairing] =
        [
            ("card", SettingsTheme.card),
            ("sunken", SettingsTheme.sunken),
        ].flatMap { name, ground in
            [
                Pairing(
                    "ink on a resting button chip on \(name)",
                    SettingsTheme.ink,
                    on: ground,
                    layers: [SettingsTheme.chipRest]
                ),
                Pairing(
                    "ink on a hovered button chip on \(name)",
                    SettingsTheme.ink,
                    on: ground,
                    layers: [SettingsTheme.chipHover]
                ),
            ]
        }

    /// A glyph-only icon chip's glyph over its lift, on every
    /// ground one is drawn on, at the glyph floor: `ink2` on a
    /// card row (and at rest beside text), in a sunken field (the
    /// search and recorder clears) and on the What's new trail
    /// banner's accent wash; `ink3` on the floating panel's close
    /// and the recorder's rejection row (card or sunken); `warningInk` on the
    /// conflict banner's amber. The trail banner draws its wash
    /// under the chip, the pairing the chip under the wash — a
    /// near-equal composite of two translucent layers.
    private static let iconChips: [Pairing] = [
        icon("ink2", SettingsTheme.ink2, on: "card", SettingsTheme.card),
        icon(
            "ink2",
            SettingsTheme.ink2,
            on: "card, resting",
            SettingsTheme.card,
            layer: SettingsTheme.chipRest
        ),
        icon(
            "ink2",
            SettingsTheme.ink2,
            on: "sunken",
            SettingsTheme.sunken
        ),
        icon(
            "ink2",
            SettingsTheme.ink2,
            on: "the trail banner",
            SettingsTheme.card,
            wash: (
                SettingsTheme.accent,
                Double(SettingsTheme.searchNoticeFillOpacity)
            )
        ),
        icon("ink3", SettingsTheme.ink3, on: "panel", SettingsTheme.panel),
        icon("ink3", SettingsTheme.ink3, on: "card", SettingsTheme.card),
        icon(
            "ink3",
            SettingsTheme.ink3,
            on: "sunken",
            SettingsTheme.sunken
        ),
        icon(
            "warningInk",
            SettingsTheme.warningInk,
            on: "warningSurface",
            SettingsTheme.warningSurface
        ),
    ]

    private static func icon(
        _ inkName: String,
        _ ink: Color,
        on groundName: String,
        _ ground: Color,
        layer: Color = SettingsTheme.chipHover,
        wash: (color: Color, alpha: Double)? = nil
    ) -> Pairing {
        Pairing(
            "\(inkName) glyph on an icon chip on \(groundName)",
            ink,
            on: ground,
            layers: [layer],
            washedWith: wash,
            floor: 3.0
        )
    }

    /// A choice chip's label — a layer, a preset share or weight
    /// — when chosen, on the accent wash in place of the rest
    /// fill; unchosen it is a button chip's (`buttonChips`, and
    /// the jump chips' rows for the page).
    private static let choiceChips: [Pairing] =
        [
            ("card", SettingsTheme.card),
            ("sunken", SettingsTheme.sunken),
            ("page", SettingsTheme.page),
        ].map { name, ground in
            Pairing(
                "ink on a chosen choice chip on \(name)",
                SettingsTheme.ink,
                on: ground,
                washedWith: (
                    SettingsTheme.accent,
                    ChoiceChip.selectedWashOpacity
                )
            )
        }

    static let chips: [Pairing] =
        segments + buttonChips + iconChips + choiceChips

    /// The opacity of the retired `primary` track, which read as a
    /// well in light — #2047's defect was dark alone — so its
    /// light separation is the floor the token may not drop under.
    private static let retiredTrackAlpha = 0.08

    /// A segmented track is a shape, not text: what keeps it
    /// visible is its composite separating from the ground it
    /// sits on, in both appearances, by no less than the retired
    /// track did in light on that same ground.
    @Test("a segmented track separates from every ground it sits on")
    func trackSeparatesFromItsGround() throws {
        let grounds = [
            ("card", SettingsTheme.card),
            ("sunken", SettingsTheme.sunken),
            ("page", SettingsTheme.page),
        ]
        for (name, ground) in grounds {
            // `primary` is itself translucent, so the retired
            // track drew at the product of the two alphas.
            let floor = try ThemeContrast.contrast(
                Color.primary,
                over: ground,
                inkAlpha: Self.retiredTrackAlpha
                    * ThemeContrast.resolvedAlpha(
                        Color.primary,
                        dark: false
                    ),
                dark: false
            )
            for dark in [false, true] {
                let track = try ThemeContrast.contrast(
                    SettingsTheme.trackFill,
                    over: ground,
                    inkAlpha: try ThemeContrast.resolvedAlpha(
                        SettingsTheme.trackFill,
                        dark: dark
                    ),
                    dark: dark
                )
                #expect(
                    track >= floor,
                    Comment(
                        rawValue: "\(name) "
                            + (dark ? "dark" : "light")
                            + String(
                                format: ": track %.3f under %.3f",
                                track,
                                floor
                            )
                    )
                )
            }
        }
    }
}
