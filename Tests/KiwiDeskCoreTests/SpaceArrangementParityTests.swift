import Foundation
import Testing

@testable import KiwiDeskCore

/// `SpaceArrangement` hand-mirrors `Space`'s stored fields for
/// layout undo (#3515, parity-tests.md): every field is copied, or
/// ruled out here with its reason, `Space.restore` writes back
/// every field it copied, and an undo rebase carries every
/// window-keyed field for a window it inserts (#3601).
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
        let copied = labels(SpaceArrangement(space, sessionSizes: sizing))
            .subtracting(["sessionSizes"])
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
        let saved = SpaceArrangement(source, sessionSizes: sizing)
        // `init` copies each field's VALUE, read off `Space` itself.
        let fields = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: source).children
                .compactMap { c in c.label.map { ($0, "\(c.value)") } }
        )
        for child in Mirror(reflecting: saved).children
        where child.label != "sessionSizes" {
            let label = child.label ?? "?"
            #expect("\(child.value)" == fields[label], "\(label)")
        }
        var target = Space(id: SpaceID("1"), mode: .track, windows: [a, b])
        let wrote = target.restore(saved)
        #expect(wrote)
        let restored = SpaceArrangement(target, sessionSizes: sizing)
        #expect(restored == saved)
    }
    @Test("an inserted window carries every window-keyed field")
    func insertCarriesWindowFields() {
        let a = WindowID(1)
        let new = WindowID(9)
        var live = Space(
            id: SpaceID("1"),
            mode: .track,
            windows: [a, new],
            stackWeights: [new: 2],
            trackBreaks: [new],
            handedBreaks: [new],
            trackWeights: [new: 1.5]
        )
        live.runSizes = [new: RunSize(share: 0.6, zone: 1)]
        let after = SpaceArrangement(live, sessionSizes: sizing)
        let step = SpaceArrangement(
            Space(id: SpaceID("1"), mode: .track, windows: [a]),
            sessionSizes: sizing
        )
        let rebased = step.inserting(
            new,
            placement: .last,
            anchor: nil,
            from: after
        )
        // Every window-keyed field: the fixture fills it, so a new
        // one reads empty here until the fixture and `inserting`
        // carry it too.
        let keyed = Mirror(reflecting: after).children.filter {
            "\(type(of: $0.value))".contains("WindowID")
                && $0.label != "windows"
        }
        #expect(keyed.count >= 5)
        let carried = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: rebased).children
                .compactMap { c in c.label.map { ($0, "\(c.value)") } }
        )
        for child in keyed {
            let label = child.label ?? "?"
            #expect("\(child.value)" != "[:]", "\(label) unfilled")
            #expect("\(child.value)" != "[]", "\(label) unfilled")
            #expect(carried[label] == "\(child.value)", "\(label)")
        }
    }
}
