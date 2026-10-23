import Foundation
import Testing

/// `animations.on_peek` reaches the bars' one motion home where the
/// shelf's other paces do (#2563): the bar pass writes
/// `BarMotion.peekMotion` from the settings, and both peek motions
/// read it.
@Suite("Peek motion wiring (#2563)")
struct PeekMotionWiringTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    @Test("The bar pass feeds the switch to BarMotion")
    func barPassFeedsIt() throws {
        let shelf = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "App/KiwiCore+Shelf.swift"
            )
        )
        #expect(
            shelf.contains(
                "BarMotion.peekMotion = settings.animations.onPeek"
            )
        )
    }

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
