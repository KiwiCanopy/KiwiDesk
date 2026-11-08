import Foundation
import Testing

/// The Tile refusal's pill leads with "Can't tile." (owner,
/// 2026-11-08); the bar menu's greyed Tile row keeps the bare
/// reason. The pill never renders under test, so the wiring is
/// held by `cueTileRefusal`'s shape.
@Suite("Tile refusal pill lead wiring")
struct TileRefusalPillLeadNeedleTests {
    @Test("cueTileRefusal flashes the pill sentence")
    func cueFlashesLead() throws {
        let body = try SourceScan.functionBody(
            of: "cueTileRefusal",
            in: "KiwiCore+SizeLimitPill.swift",
            under: "App"
        )
        #expect(body.contains("text: reason.pillSentence"))
        #expect(!body.contains("text: reason.sentence"))
    }
}
