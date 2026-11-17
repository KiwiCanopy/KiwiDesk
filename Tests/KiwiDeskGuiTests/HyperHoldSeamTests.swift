import Foundation
import Testing

/// Every gesture reader builds its chord with the Hyper hold
/// (#3407 ▸ Amendment). `ScrollChord(flags:hyper:)` takes `hyper`
/// with no default, so a reader cannot leave it out; this holds
/// that each passes its own hold's reading rather than a constant.
/// The scroll and pointer taps are driven behaviourally by
/// `HyperHoldWiringTests`, and each front's hand-off to its factory
/// by `HyperHoldFactoryTests`; the touch reader and the three live
/// factories run only on a device, so this scan is their one net.
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

    @Test("each live factory forwards the hold it is handed")
    func factoriesForwardTheHold() throws {
        for (name, call) in [
            (
                "ScrollGestures.swift",
                "ScrollGestureTap.live(hyper: $0, deliver: $1)"
            ),
            (
                "PointerConsumers.swift",
                "PointerTap.live(mask: $0, hyper: $1, deliver: $2)"
            ),
            (
                "TouchGestures.swift",
                "TouchReader.live(hyper: $0, deliver: $1)"
            ),
        ] {
            let source = try String(
                contentsOf: Self.events.appendingPathComponent(name),
                encoding: .utf8
            )
            #expect(source.contains(call), "\(name)")
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
