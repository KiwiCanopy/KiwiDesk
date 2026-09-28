import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk

/// The sheen slider reads as a darker/lighter scale at rest (owner
/// 2026-09-28): moon and sun at the ends, a faint ramp on the
/// track, and the origin notch above and below the knob at Off.
@MainActor
@Suite("The sheen slider's lightness scale")
struct SheenLightnessTests {
    private func slider(_ value: Double, origin: Double?) -> SettingsSlider {
        SettingsSlider(
            value: .constant(value),
            range: -1...1,
            step: 0.05,
            label: "",
            spokenValue: "",
            origin: origin
        )
    }

    /// The step grid may land an ulp off 0; that is still Off.
    @Test("Off is judged within half a step of the origin")
    func restsOnOrigin() {
        #expect(slider(0, origin: 0).restsOnOrigin)
        #expect(slider(1e-17, origin: 0).restsOnOrigin)
        // One grid step either side, as the slider computes it
        // (-0.0499…), so a full-step tolerance reds too.
        #expect(!slider(-1 + 19 * 0.05, origin: 0).restsOnOrigin)
        #expect(!slider(-1 + 21 * 0.05, origin: 0).restsOnOrigin)
        #expect(!slider(0, origin: nil).restsOnOrigin)
    }

    @Test("the Sheen row asks for the lightness scale")
    func rowAsks() throws {
        let source = try strippedSource("Looks/SheenRow.swift")
        let call = try #require(
            SourceScan.callArguments(of: "SettingsSlider(", in: source)
        )
        #expect(call.contains("lightness: true"))
    }

    /// Each piece is drawn only under `lightness`, so no other
    /// slider grows glyphs, a ramp or the Off marks.
    @Test("the slider draws each piece under its gate")
    func sliderDrawsThePieces() throws {
        let source = try strippedSource("Common/SettingsSlider.swift")
        let body = try #require(
            SourceScan.declarationBody(after: "var body:", in: source)
        )
        #expect(body.contains("if lightness { endGlyph(\"moon.fill\") }"))
        #expect(body.contains("if lightness { endGlyph(\"sun.max.fill\") }"))
        let track = try #require(
            SourceScan.declarationBody(after: "func track(", in: source)
        )
        #expect(
            track.contains("if lightness && isEnabled { lightnessRamp }")
        )
        #expect(
            track.contains(
                "if lightness && restsOnOrigin && !dragging {"
                    + " originMarks("
            )
        )
    }

    private func strippedSource(_ path: String) throws -> String {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/" + path
            )
        return try SourceScan.strippedSource(at: file)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
