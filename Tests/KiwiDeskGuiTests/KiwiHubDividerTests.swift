import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// **KiwiHub's dividers take the look's ink under the tint and the
/// system separator off it** (#2596). The ink is KiwiHub's paint,
/// handed down by the panel chrome; which view draws through it is
/// needled on its use sites.
@Suite("KiwiHub dividers (#2596)")
@MainActor
struct KiwiHubDividerTests {
    private static let gui = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDesk")

    private static func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: gui.appendingPathComponent(path)
        )
    }

    @Test(
        "The paint carries the divider ink only under the tint",
        arguments: [true, false]
    )
    func paintCarriesTheInk(tinted: Bool) throws {
        try #require(GlassChromeVariant.drawable, "no glass below 26")
        var settings = TilingSettings()
        settings.kiwishelf.tintHubAndPlates = tinted
        let glass = PanelGlass(settings: settings)
        // The chrome's own resolution: no inks for an untinted glass.
        for increased in [false, true] {
            let ink = glass.shelf?.panelInk(increaseContrast: increased)
            let paint = KiwiHubPaint.of(glass, ink: ink)
            guard tinted else {
                #expect(ink == nil)
                #expect(paint.divider == nil)
                continue
            }
            let drawn = settings.kiwishelf.panelInk(
                increaseContrast: increased
            )
            #expect(paint.divider == Color(kiwiHex: drawn.divider))
        }
    }

    /// Both of KiwiHub's dividers draw through the one panel
    /// divider, which keeps the system separator for an untinted
    /// panel.
    @Test("KiwiHub draws its dividers through the panel divider")
    func dividersRouteThroughThePaint() throws {
        let panel = try Self.source("Jump/JumpPanelView.swift")
        #expect(panel.occurrences(of: "PanelDivider()") == 2)
        // No file of KiwiHub or a cue plate draws a bare `Divider()`
        // but the panel divider's own untinted fallback; every
        // `Divider()` elsewhere is a `PanelDivider()`, which spells it.
        var scanned = 0
        for directory in ["Jump", "CuePlate"] {
            let files = try FileManager.default.contentsOfDirectory(
                atPath: Self.gui.appendingPathComponent(directory).path
            ).filter { $0.hasSuffix(".swift") }
            for file in files where file != "KiwiHubPaint.swift" {
                let body = try Self.source("\(directory)/\(file)")
                scanned += 1
                #expect(
                    body.occurrences(of: "Divider()")
                        == body.occurrences(of: "PanelDivider()"),
                    "\(directory)/\(file)"
                )
            }
        }
        #expect(scanned > 2)
        let paint = try Self.source("Jump/KiwiHubPaint.swift")
            .filter { !$0.isWhitespace }
        #expect(paint.contains("iflethairline=paint.divider{"))
        #expect(paint.contains(".fill(hairline)"))
        #expect(paint.contains("}else{Divider()}"))
    }
}
