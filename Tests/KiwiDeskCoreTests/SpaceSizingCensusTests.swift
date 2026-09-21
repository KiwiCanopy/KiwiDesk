import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Every stored property of `Space` is either SIZING — cleared by
/// `Space.resetSizing()` — or STRUCTURE, named in the register
/// below (#764). Discovered by reflection over a fixture that
/// sets every property away from its default, so a store added
/// tomorrow reds until it is classified. `WorkspaceManager
/// .setMode` clears a DIFFERENT set on purpose — a mode reseed
/// drops the track weights while the in-track shares
/// (`stackWeights`) survive by ruling
/// (`docs/accepted-limitations.md`) — and is not held here.
@Suite("Space sizing census (#764)")
struct SpaceSizingCensusTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)

    /// What a reset keeps, with the reason each is structure and
    /// not size. `id` and `mode` are identity; the rest is what the
    /// user arranged rather than what `resize` accumulated.
    private let structure: [String: String] = [
        "id": "identity",
        "mode": "the layout, chosen",
        "windows": "the flat array — membership and order",
        "focused": "the focus, not a size",
        "scrollRest": "the viewport's place, re-anchored by #966",
        "trackBreaks": "where the user broke the row (#128)",
        "handedBreaks": "a break's provenance (#1387)",
    ]

    /// Every property set away from its default — the census is
    /// only as complete as this fixture, which `everyFieldIsSet`
    /// holds.
    private func fixture() -> Space {
        var space = Space(id: SpaceID("1"))
        space.mode = .track
        space.windows = [w1, w2]
        space.focused = w1
        space.stackWeights = [w1: 2]
        space.scrollRest = ScrollRest(offset: 40)
        space.trackBreaks = [w2]
        space.handedBreaks = [w2]
        space.trackWeights = [w1: 1.5]
        space.sessionRatios.masterRatio = 0.6
        return space
    }

    private func fields(_ space: Space) -> [String: Any] {
        var out: [String: Any] = [:]
        for child in Mirror(reflecting: space).children {
            if let label = child.label { out[label] = child.value }
        }
        return out
    }

    private func isDefault(_ label: String, _ value: Any) -> Bool {
        let defaults = fields(Space(id: SpaceID("1")))
        guard let base = defaults[label] else { return false }
        return String(describing: value) == String(describing: base)
    }

    @Test("The fixture sets every stored property")
    func everyFieldIsSet() {
        for (label, value) in fields(fixture()) where label != "id" {
            #expect(!isDefault(label, value), "\(label) at default")
        }
    }

    @Test("Every property is cleared by the reset or named structure")
    func everyPropertyIsClassified() {
        var space = fixture()
        space.resetSizing()
        let after = fields(space)
        var cleared: Set<String> = []
        for (label, value) in after {
            if let reason = structure[label] {
                #expect(!reason.isEmpty)
                #expect(
                    !isDefault(label, value) || label == "id",
                    "\(label) is structure yet the reset cleared it"
                )
            } else {
                #expect(
                    isDefault(label, value),
                    Comment(
                        rawValue: "\(label) is unclassified: neither "
                            + "structure nor cleared by resetSizing()"
                    )
                )
                cleared.insert(label)
            }
        }
        // The census is not vacuous: the sizing stores are the
        // three `resize` writes into.
        #expect(cleared == ["sessionRatios", "stackWeights", "trackWeights"])
        #expect(
            Set(structure.keys).union(cleared) == Set(after.keys)
        )
    }
}
