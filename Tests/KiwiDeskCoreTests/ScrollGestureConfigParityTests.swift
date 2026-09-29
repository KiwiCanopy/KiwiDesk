import Foundation
import Testing

@testable import KiwiDeskCore

/// `ScrollGestureOverride` mirrors `ScrollGestureBase` field for
/// field (#1656, parity-tests.md): a field added to the base and
/// not the override could never be overridden per profile, and one
/// left out of `resolved`/`diff` would be dropped on a save.
@Suite("Scroll gesture override parity")
struct ScrollGestureConfigParityTests {
    private func labels(_ value: Any) -> [String] {
        Mirror(reflecting: value).children.compactMap(\.label)
    }

    @Test("the override names every field of the base, and only those")
    func fieldsMirror() {
        let base = labels(ScrollGestureBase.defaults)
        #expect(!base.isEmpty)
        #expect(base == labels(ScrollGestureOverride()))
    }

    /// Every field differs from the base, so a resolve or a diff
    /// that forgets one reds on it.
    @Test("resolve and diff carry every field")
    func resolveAndDiffCarryEveryField() {
        let base = ScrollGestureBase.defaults
        let edited = ScrollGestureBase(
            pan: [.command, .shift],
            spaceStep: [],
            naturalTrackpad: false,
            naturalMouse: false,
            longSwipes: true,
            stepDistance: 120
        )
        for (name, value) in zip(labels(base), labels(edited)) {
            #expect(name == value)
        }
        let over = ScrollGestureOverride.diff(base: base, edited: edited)
        #expect(
            Mirror(reflecting: over!).children.allSatisfy {
                "\($0.value)" != "nil"
            }
        )
        #expect(over?.resolved(onto: base) == edited)
    }

    /// The "Applies to" table keys one row per field (#1656): a
    /// field `ScrollGestureField` misses is one no checklist can
    /// reach, and the save would drop it.
    @Test("ScrollGestureField reads and writes every field")
    func fieldsCoverTheBase() {
        let base = ScrollGestureBase.defaults
        let edited = ScrollGestureBase(
            pan: [.command, .shift],
            spaceStep: [],
            naturalTrackpad: false,
            naturalMouse: false,
            longSwipes: true,
            stepDistance: 120
        )
        #expect(ScrollGestureField.allCases.count == labels(base).count)
        #expect(base.writing(edited.fields) == edited)
        let over = ScrollGestureOverride.diff(base: base, edited: edited)
        #expect(over?.fields == edited.fields)
    }
}
