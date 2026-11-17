import Foundation
import Testing

/// Every gesture reader builds its chord with the Hyper hold
/// (#3407 ▸ Amendment). `ScrollChord(flags:hyper:)` takes `hyper`
/// with no default, so a reader cannot leave it out; this holds
/// that each passes its own hold's reading rather than a constant.
/// The scroll and pointer taps are driven behaviourally by
/// `HyperHoldWiringTests`; the touch reader runs only on a device,
/// so this scan is its one net.
@Suite("Gesture readers read the Hyper hold")
struct HyperHoldSeamTests {
    private static let events = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore/Events")

    @Test("each chord build passes the hold, once per reader")
    func readersPassTheHold() throws {
        for name in [
            "ScrollGestureTap.swift", "PointerTap.swift", "TouchReader.swift",
        ] {
            let source = try String(
                contentsOf: Self.events.appendingPathComponent(name),
                encoding: .utf8
            )
            #expect(!source.isEmpty, "\(name)")
            #expect(
                source.components(separatedBy: "hyper: hyper.isHeld")
                    .count == 2,
                "\(name)"
            )
        }
    }

    @Test("an event's chord is built only in the three readers")
    func noOtherChordBuild() throws {
        let core = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let files = try FileManager.default
            .subpathsOfDirectory(atPath: core.path)
            .filter { $0.hasSuffix(".swift") }
        var builders: Set<String> = []
        for path in files {
            let source = try String(
                contentsOf: core.appendingPathComponent(path),
                encoding: .utf8
            )
            let squeezed = source.filter { !$0.isWhitespace }
            if squeezed.contains("ScrollChord(flags:")
                || squeezed.contains("ScrollSample(flags:")
            {
                builders.insert((path as NSString).lastPathComponent)
            }
        }
        #expect(
            builders == [
                "ScrollSample.swift", "ScrollGestureTap.swift",
                "PointerTap.swift", "TouchReader.swift",
            ]
        )
    }
}
