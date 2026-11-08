import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The hover edge against the selected stroke (#3042, owner
/// 2026-11-08): a hovered tile must not pass for a selected one, so
/// `hoverEdge` separates from `accent` by `ColorVision`'s floor in
/// both appearances, the measure that sees hue as well as luminance.
extension SettingsThemeContrastTests {
    @Test("the hover edge separates from the selected accent")
    func hoverEdgeSeparatesFromAccent() throws {
        for dark in [false, true] {
            let edge = try Self.hex(SettingsTheme.hoverEdge, dark: dark)
            let accent = try Self.hex(SettingsTheme.accent, dark: dark)
            let separation = try #require(
                ColorVision.separation(edge, accent)
            )
            #expect(
                separation >= ColorVision.separationFloor,
                Comment(
                    rawValue: (dark ? "dark" : "light")
                        + String(
                            format: ": %@ vs %@ separates %.1f",
                            edge,
                            accent,
                            separation
                        )
                )
            )
        }
    }

    /// A token resolved in one appearance, as `#RRGGBB`.
    private static func hex(_ color: Color, dark: Bool) throws -> String {
        let rgb = try ThemeContrast.resolved(color, dark: dark)
        return "#"
            + [rgb.r, rgb.g, rgb.b]
            .map { String(format: "%02X", Int(($0 * 255).rounded())) }
            .joined()
    }
}
