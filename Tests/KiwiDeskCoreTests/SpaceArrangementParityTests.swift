import Foundation
import Testing

@testable import KiwiDeskCore

/// `SpaceArrangement` hand-mirrors `Space`'s stored fields for
/// layout undo (#3515, parity-tests.md): every field is copied, or
/// ruled out here with its reason, and `Space.restore` writes back
/// every field it copied.
@Suite("Space arrangement parity (#3515)")
struct SpaceArrangementParityTests {
    /// `Space` fields a step leaves out, each with why.
    static let ruledOut: [String: String] = [
        "id": "the stack's key, never restored",
        "focused": "focus is not part of the arrangement",
        "scrollRest": "a retile rewrites the viewport",
        "runHeads": "written back after every retile",
        "runTails": "written back after every retile",
        "maximized": "the Maximize's own doors end and return it",
    ]

    private func labels(_ value: Any) -> Set<String> {
        Set(Mirror(reflecting: value).children.compactMap(\.label))
    }

    private let sizing = SpaceSizing(
        key: SessionSizingKey(desktop: nil, arrangement: nil),
        ratios: SessionRatios()
    )

    @Test("every Space field is copied or ruled out")
    func fieldsAreMirrored() {
        let space = Space(id: SpaceID("1"))
        let copied = labels(SpaceArrangement(space, sizing: sizing))
            .subtracting(["sizing"])
        let stored = labels(space)
        #expect(copied.union(Self.ruledOut.keys) == stored)
        #expect(copied.isDisjoint(with: Self.ruledOut.keys))
    }

    @Test("restore writes back every copied field")
    func restoreRoundTrips() {
        let a = WindowID(1)
        let b = WindowID(2)
        var source = Space(
            id: SpaceID("1"),
            mode: .track,
            windows: [b, a],
            stackWeights: [a: 2],
            trackBreaks: [a],
            handedBreaks: [b],
            trackWeights: [b: 1.5]
        )
        source.runSizes = [a: RunSize(share: 0.6, zone: 1)]
        let saved = SpaceArrangement(source, sizing: sizing)
        // `init` copies each field's VALUE, read off `Space` itself.
        let fields = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: source).children
                .compactMap { c in c.label.map { ($0, "\(c.value)") } }
        )
        for child in Mirror(reflecting: saved).children
        where child.label != "sizing" {
            let label = child.label ?? "?"
            #expect("\(child.value)" == fields[label], "\(label)")
        }
        var target = Space(id: SpaceID("1"), mode: .track, windows: [a, b])
        let wrote = target.restore(saved)
        #expect(wrote)
        let restored = SpaceArrangement(target, sizing: sizing)
        #expect(restored == saved)
    }
}
