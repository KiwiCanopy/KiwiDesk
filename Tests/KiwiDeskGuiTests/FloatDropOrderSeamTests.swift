import Foundation
import Testing

/// The float drop's three steps run in one order (#1686): the
/// drop's live frame is folded, then the float is re-filed, then
/// clamped clear of the bars. Folded late, the re-file's retile
/// judges a lagging echo; clamped early, the drop is pushed off
/// the ORIGIN's strips while the window sits on another display.
/// No fixture paints a strip on a fake display, so the order in
/// the source is the guard.
@Suite("The float drop folds, re-files, then clamps (#1686)")
struct FloatDropOrderSeamTests {
    @Test("fold, then re-file, then clamp")
    func stepsRunInOrder() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Tiling/KiwiCore+Drag.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        let body = try #require(
            SourceScan.declarationBody(
                after: "func handleDragEnd(",
                in: source
            )
        )
        let steps = [
            "state.apply(.windowMoved(id, frame))",
            "relocateDroppedFloat(id)",
            "floatFrameClampedClearOfBars(",
        ]
        let offsets = try steps.map { step in
            try #require(
                body.range(of: step)?.lowerBound,
                "\(step) is missing from handleDragEnd"
            )
        }
        #expect(offsets == offsets.sorted())
    }
}
