import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// A marked or chosen chip is told from its neighbours by fill
/// alone, so each mark separates by `ColorVision`'s floor from a
/// resting neighbour AND a hovered one, in both appearances, on the
/// ground it is drawn on (5.0.0): the jump chip on `page`, the icon
/// cell on `card`, the chosen choice chip on every ground a choice
/// strip sits on. Spend: a handful of colour resolutions on the
/// main actor.
@MainActor
@Suite("Chip mark separation")
struct ChipMarkSeparationTests {
    /// The drawn colour of `layers` composited in order over
    /// `ground`, each at the alpha it resolves to.
    private func drawn(
        _ layers: [Color],
        over ground: Color,
        dark: Bool
    ) throws -> String {
        var hex = try hexString(ground, dark: dark, alpha: nil)
        for layer in layers {
            let alpha = try ThemeContrast.resolvedAlpha(layer, dark: dark)
            let top = try hexString(layer, dark: dark, alpha: alpha)
            hex = try #require(ColorVision.composite(top, over: hex))
        }
        return hex
    }

    private func hexString(
        _ color: Color,
        dark: Bool,
        alpha: Double?
    ) throws -> String {
        let rgb = try ThemeContrast.resolved(color, dark: dark)
        let parts = [rgb.r, rgb.g, rgb.b] + (alpha.map { [$0] } ?? [])
        return "#"
            + parts
            .map { String(format: "%02X", Int(($0 * 255).rounded())) }
            .joined()
    }

    private func expectSeparates(
        _ mark: [Color],
        on ground: Color,
        _ name: String
    ) throws {
        for dark in [false, true] {
            let marked = try drawn(mark, over: ground, dark: dark)
            for (neighbour, fill) in [
                ("resting", SettingsTheme.chipRest),
                ("hovered", SettingsTheme.chipHover),
            ] {
                let other = try drawn([fill], over: ground, dark: dark)
                let separation = try #require(
                    ColorVision.separation(marked, other)
                )
                #expect(
                    separation >= ColorVision.separationFloor,
                    Comment(
                        rawValue: "\(name) vs \(neighbour) "
                            + (dark ? "dark" : "light")
                            + String(format: ": %.1f", separation)
                    )
                )
            }
        }
    }

    /// A mark is the accent at its own alpha: retuning the accent
    /// reds here until both marks follow it (each token is a hex
    /// literal the token table's source scans read).
    @Test("each mark wears the accent's hue")
    func marksAreTheAccent() throws {
        for mark in [SettingsTheme.chipMarked, SettingsTheme.iconCellMarked] {
            for dark in [false, true] {
                let a = try ThemeContrast.resolved(mark, dark: dark)
                let b = try ThemeContrast.resolved(
                    SettingsTheme.accent,
                    dark: dark
                )
                #expect(a == b)
            }
        }
    }

    @Test("the marked jump chip separates from its neighbours")
    func jumpChip() throws {
        try expectSeparates(
            [SettingsTheme.chipRest, ShortcutsJumpChip.markFill(true)],
            on: SettingsTheme.page,
            "jump chip"
        )
    }

    @Test("the marked icon cell separates from its neighbours")
    func iconCell() throws {
        try expectSeparates(
            [SettingsTheme.chipRest, IconCellStyle.markFill(true)],
            on: SettingsTheme.card,
            "icon cell"
        )
    }

    @Test("the chosen choice chip separates from its neighbours")
    func choiceChip() throws {
        let grounds = [
            ("card", SettingsTheme.card),
            ("sunken", SettingsTheme.sunken),
            ("page", SettingsTheme.page),
            ("panel", SettingsTheme.panel),
        ]
        for (name, ground) in grounds {
            try expectSeparates(
                [ChoiceChip.fill(selected: true, hovering: false)],
                on: ground,
                "choice chip on \(name)"
            )
        }
    }
}
