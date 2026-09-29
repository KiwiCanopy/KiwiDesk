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

    /// The sparse `Codable` is a hand-kept field list: every field
    /// differs from its default, so a dropped encode or decode line
    /// comes back as the default and reds here.
    @Test("every field round-trips through JSON")
    func everyFieldRoundTrips() throws {
        let edited = ScrollGestureBase(
            pan: [.command, .shift],
            spaceStep: [],
            naturalTrackpad: false,
            naturalMouse: false,
            longSwipes: true,
            stepDistance: 120
        )
        // Every field off its default, derived rather than
        // trusted: a new field left default here is one unwatched.
        let defaults = Mirror(reflecting: ScrollGestureBase.defaults)
            .children.map { "\($0.value)" }
        for (index, child) in Mirror(reflecting: edited).children
            .enumerated()
        {
            #expect(
                "\(child.value)" != defaults[index],
                "\(child.label ?? "?") is left at its default"
            )
        }
        let coder = (JSONEncoder(), JSONDecoder())
        #expect(
            try coder.1.decode(
                ScrollGestureBase.self,
                from: coder.0.encode(edited)
            ) == edited
        )
        let over = try #require(
            ScrollGestureOverride.diff(base: .defaults, edited: edited)
        )
        #expect(
            try coder.1.decode(
                ScrollGestureOverride.self,
                from: coder.0.encode(over)
            ) == over
        )
    }
}
