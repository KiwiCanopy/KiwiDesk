import Foundation
import Testing

@testable import KiwiDeskCore

/// The accent seal's three state fills, under protanopia (#1198).
///
/// Since #1198 the seal says "available", "being pressed" and
/// "unavailable" by changing its FILL and nothing else — same
/// silhouette, same ink, same stroke. That makes the whole
/// enabled/disabled distinction a colour judgement, on a primary
/// that is green, which is the one hue protanopia takes. So the
/// pairs owe the same floor the bars' and the drag overlay's do.
///
/// Both hexes are PARSED from `SettingsTheme.swift`, so a
/// retune moves the measurement with it instead of leaving a
/// stale copy behind (a number-pin derives, never restates).
@Suite("Accent state separation")
struct AccentStateSeparationTests {
    private func themeSource() throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "Tests" {
            url.deleteLastPathComponent()
            try #require(url.path != "/")
        }
        url.deleteLastPathComponent()
        let source = try String(
            contentsOf: url.appendingPathComponent(
                "Sources/KiwiDesk/Settings/SettingsTheme.swift"
            ),
            encoding: .utf8
        )
        try #require(!source.isEmpty)
        return source
    }

    /// `let name = token(light: 0xAA_BB_CC, dark: 0xDD_EE_FF` →
    /// one mode's hex. The live fills differ per mode, so the
    /// floor is measured in each.
    private func fill(
        _ name: String,
        dark: Bool,
        in source: String
    ) throws -> String {
        let squashed =
            source
            .split(whereSeparator: \.isWhitespace)
            .joined()
        let start = try #require(
            squashed.range(of: "let\(name)=token(light:0x"),
            Comment(rawValue: "no such token: \(name)")
        )
        let lightHex = squashed[start.upperBound...]
            .prefix { $0.isHexDigit || $0 == "_" }
        let rest = squashed[start.upperBound...]
            .dropFirst(lightHex.count + ",dark:0x".count)
        let hex = (dark ? rest : lightHex)
            .prefix { $0.isHexDigit || $0 == "_" }
            .replacingOccurrences(of: "_", with: "")
        try #require(hex.count == 6)
        return "#" + hex
    }

    /// Disabled must separate from BOTH live fills.
    ///
    /// Against `accent` is the pair that carries the meaning —
    /// the whole answer to "does this button do anything".
    /// Against `accentPressed` is the thinner one, and it is
    /// measured because the two ARE co-visible: the preset
    /// preview sheet's Done wears the seal and is capped well
    /// under the window, so it can sit pressed beside a save
    /// pill whose Save is disabled — which is the pill's
    /// drift-without-edits state, the one #1198 measured. An
    /// earlier draft of this suite left that clause out on the
    /// premise that no two seal buttons are ever on screen
    /// together; review found the premise false.
    @Test("the disabled fill separates from both live fills")
    func disabledSeparatesFromLiveFills() throws {
        let source = try themeSource()
        for dark in [false, true] {
            let off = try fill(
                "accentDisabled",
                dark: dark,
                in: source
            )
            for name in ["accent", "accentPressed"] {
                let live = try fill(name, dark: dark, in: source)
                let measured = try #require(
                    ColorVision.separation(live, off)
                )
                #expect(
                    measured >= ColorVision.separationFloor,
                    Comment(
                        rawValue: String(
                            format:
                                "%@ vs accentDisabled (%@) "
                                + "separates by %.1f under "
                                + "protanopia, under the %.0f "
                                + "floor — an unavailable button "
                                + "would still read as available",
                            name,
                            dark ? "dark" : "light",
                            measured,
                            ColorVision.separationFloor
                        )
                    )
                )
            }
        }
    }
}
