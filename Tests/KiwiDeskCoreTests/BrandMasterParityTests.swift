import Foundation
import Testing

/// The two wordmark masters are a hand-mirrored geometry pair, and
/// `.claude/rules/parity-tests.md` says a shipped mirror carries a
/// parity test. This one is not hypothetical: on `main` before
/// #479 the dark master had **five** paths against the light
/// master's nine — a completely different decomposition — which is
/// how a whole-logo gold recolour survived a rebrand undetected.
/// A README sentence ("if you edit one, mirror the edit in the
/// other") is what failed; this is the machine-checkable version.
///
/// The invariant: the two masters are identical **except** for the
/// colour of the paths marked `class="ink"` — the lettering. The
/// symbol must be byte-identical, because the whole #479 decision
/// is that a mark holds one hue across themes.
@Suite("Brand master parity")
struct BrandMasterParityTests {
    private var assets: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("assets")
    }

    private func master(_ name: String) throws -> String {
        try String(
            contentsOf: assets.appendingPathComponent(name),
            encoding: .utf8
        )
    }

    /// Every `<path …/>` element, in document order.
    private func paths(_ svg: String) -> [String] {
        svg.components(separatedBy: "<path ")
            .dropFirst()
            .map { "<path " + $0.components(separatedBy: "/>")[0] }
    }

    /// Strips `fill="…"` / `stroke="…"` so two paths compare on
    /// geometry and every other attribute.
    private func colorless(_ path: String) -> String {
        var out = path
        for attribute in ["fill", "stroke"] {
            while let start = out.range(of: "\(attribute)=\"") {
                guard
                    let end = out.range(
                        of: "\"",
                        range: start.upperBound..<out.endIndex
                    )
                else { break }
                out.replaceSubrange(
                    start.lowerBound..<end.upperBound,
                    with: ""
                )
            }
        }
        return out
    }

    @Test("The two wordmark masters share one geometry")
    func mastersShareGeometry() throws {
        let light = paths(try master("logo_wordmark.svg"))
        let dark = paths(try master("logo_wordmark_dark.svg"))
        #expect(light.count == dark.count)
        #expect(!light.isEmpty)
        for (index, pair) in zip(light, dark).enumerated() {
            #expect(
                colorless(pair.0) == colorless(pair.1),
                Comment(
                    rawValue:
                        "wordmark path \(index) differs beyond "
                        + "colour — the masters have drifted apart "
                        + "(this is the #479 failure mode)"
                )
            )
        }
    }

    @Test("Only the lettering is themed; the symbol is not")
    func onlyTheInkDiffers() throws {
        let light = paths(try master("logo_wordmark.svg"))
        let dark = paths(try master("logo_wordmark_dark.svg"))
        var themed = 0
        for (lightPath, darkPath) in zip(light, dark) {
            let isInk = lightPath.contains("class=\"ink\"")
            if lightPath == darkPath { continue }
            themed += 1
            // A path that differs at all must be lettering. If a
            // symbol path ever differs, the mark has started
            // re-hueing per theme — the thing #479 retired.
            #expect(
                isInk,
                Comment(
                    rawValue:
                        "a non-ink path differs between the two "
                        + "masters: the symbol must hold one hue "
                        + "across themes (#479)"
                )
            )
        }
        // And the lettering must actually be themed, or the dark
        // master is a pointless copy of the light one.
        #expect(themed > 0)
    }

    @Test("A retired amber never returns to a brand master")
    func noAmberInAnyMaster() throws {
        // The exact palette the pre-#439 dark logo shipped. A
        // regression here means someone restored an old master or
        // re-derived one from history.
        let retired = [
            "#8b6d22", "#dbb542", "#b18c2f", "#f2e4bb", "#ddcba6",
            "#bca274", "#86641b", "#8b6b21", "#b08c32", "#d0be98",
            "#f1e5be",
        ]
        for name in [
            "logo.svg", "logo_wordmark.svg",
            "logo_wordmark_dark.svg", "logo_mono.svg",
        ] {
            let svg = try master(name).lowercased()
            for hex in retired {
                #expect(
                    !svg.contains(hex),
                    Comment(rawValue: "\(name) still has \(hex)")
                )
            }
        }
    }
}
