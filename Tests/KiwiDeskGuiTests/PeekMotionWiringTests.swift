import Foundation
import Testing

/// `animations.on_peek` reaches the bars' one motion home where the
/// shelf's other paces do (#2563): the bar pass writes
/// `BarMotion.peekMotion` from the settings (`PeekMotionTests` ▸
/// `verbWrites` reds on that line), and both peek motions read it.
@Suite("Peek motion wiring (#2563)")
struct PeekMotionWiringTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    @Test("Both peek motions read the switch")
    func bothMotionsReadIt() throws {
        for file in ["Bar/BarMotion+Fade.swift", "Bar/BarMotion+Morph.swift"] {
            let text = try SourceScan.strippedSource(
                at: Self.core.appendingPathComponent(file)
            )
            #expect(text.contains("onPeek: peekMotion"), "\(file)")
        }
    }
}
