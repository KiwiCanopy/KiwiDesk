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
/// Lives in this target because `ColorVision` does; both hexes
/// are PARSED from `SettingsTheme.swift`, so a retune moves the
/// measurement with it instead of leaving a stale copy behind (a
/// number-pin derives, never restates).
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

    /// `let name = token(light: 0xAA_BB_CC, …)` → the light hex.
    /// All three state fills are fixed in both modes, which the
    /// token suite pins, so one hex is the whole colour.
    private func fill(
        _ name: String,
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
        let hex = squashed[start.upperBound...]
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
        let off = try fill("accentDisabled", in: source)
        for name in ["accent", "accentPressed"] {
            let live = try fill(name, in: source)
            let measured = try #require(
                ColorVision.separation(live, off)
            )
            #expect(
                measured >= ColorVision.separationFloor,
                Comment(
                    rawValue: String(
                        format:
                            "%@ vs accentDisabled separates by "
                            + "%.1f under protanopia, under the "
                            + "%.0f floor — an unavailable "
                            + "button would still read as "
                            + "available",
                        name,
                        measured,
                        ColorVision.separationFloor
                    )
                )
            )
        }
    }
}
