import Foundation
import Testing

/// The keyboard board's two ring warnings, measured through the
/// same protanopia transform every other palette decision uses.
///
/// **The hexes are PARSED from `SettingsTheme.swift`**, never
/// restated. An earlier cut hand-wrote four values, two of which
/// matched no shipped token after the board moved onto `accent`
/// and a dedicated conflict red — so the suite was green while
/// measuring a pair the app does not draw, and the ruling in
/// `docs/design-decisions.md` rested on it.
/// `ModeGatedFrameSeparationTests` parses for exactly this
/// reason; this is the same walk.
///
/// **Each ring is measured against the ONE fill it can sit on.**
/// A reserved ring only ever rings a FREE key — a key the user
/// has bound reads bound whatever macOS thinks — and a conflict
/// ring only ever rings a BOUND one, since a collision is two of
/// the user's bindings on one key. `KeyboardCollisionTests` holds
/// the scoping that makes the second half true.
@Suite("Keyboard ring separation")
struct KeyboardRingSeparationTests {

    @Test("The reserved ring reads on the free key it rings")
    func reservedRingReadsOnFree() throws {
        let source = try themeSource()
        let free = try token("keyFree", in: source)
        let reserved = try token("keyReserved", in: source)
        for (ring, fill) in [
            (reserved.light, free.light), (reserved.dark, free.dark),
        ] {
            let separation = try #require(
                ColorVision.separation(ring, fill)
            )
            #expect(
                separation >= ColorVision.separationFloor,
                Comment(rawValue: "\(ring) on \(fill): \(separation)")
            )
        }
    }

    /// Against `accent`, which is what the board fills a bound
    /// key with — the board declares no green of its own.
    @Test("The conflict ring reads on the bound key it rings")
    func conflictRingReadsOnBound() throws {
        let source = try themeSource()
        let bound = try token("accent", in: source)
        let conflict = try token("keyConflict", in: source)
        for (ring, fill) in [
            (conflict.light, bound.light), (conflict.dark, bound.dark),
        ] {
            let separation = try #require(
                ColorVision.separation(ring, fill)
            )
            #expect(
                separation >= ColorVision.separationFloor,
                Comment(rawValue: "\(ring) on \(fill): \(separation)")
            )
        }
    }

    /// `SettingsTheme.danger` was the conflict ring for a day.
    /// It varies by appearance, and its DARK value is what fails
    /// — on a board pinned in both modes precisely so a picture
    /// of a keyboard cannot change with the window. Kept as the
    /// statement of what the dedicated token buys.
    @Test("The appearance-varying danger red would not clear it")
    func dangerWouldNotClearTheFloor() throws {
        let source = try themeSource()
        let bound = try token("accent", in: source)
        let danger = try token("danger", in: source)
        let separation = try #require(
            ColorVision.separation(danger.dark, bound.dark)
        )
        #expect(separation < ColorVision.separationFloor)
    }

    private func themeSource() throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        let source = try String(
            contentsOf: url.appendingPathComponent(
                "Sources/KiwiDesk/Settings/SettingsTheme.swift"
            ),
            encoding: .utf8
        )
        try #require(!source.isEmpty)
        return source
    }

    /// `token(light: 0xAA_BB_CC, dark: …)` → the two hexes.
    private func token(
        _ name: String,
        in source: String
    ) throws -> (light: String, dark: String) {
        let squashed =
            source
            .split(whereSeparator: \.isWhitespace)
            .joined()
        let needle = "let\(name)=token(light:0x"
        let start = try #require(
            squashed.range(of: needle),
            Comment(rawValue: name)
        )
        let rest = squashed[start.upperBound...]
        let parts = rest.split(separator: ",", maxSplits: 1)
        let light = String(parts[0])
            .replacingOccurrences(of: "_", with: "")
        let darkPart = try #require(
            String(parts[1]).range(of: "dark:0x").map {
                String(parts[1])[$0.upperBound...]
            }
        )
        let dark =
            darkPart
            .prefix { $0.isHexDigit || $0 == "_" }
            .replacingOccurrences(of: "_", with: "")
        try #require(light.count == 6 && dark.count == 6)
        return ("#" + light, "#" + dark)
    }
}
