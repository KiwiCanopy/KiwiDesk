import Foundation
import Testing

@testable import KiwiDeskCore

/// `ScrollGestureOverride` mirrors `ScrollGestureBase` field for
/// field (#1656, parity-tests.md): a field added to the base and
/// not the override could never be overridden per profile, and one
/// left out of `resolved`/`diff` would be dropped on a save. The one
/// exemption is `globalOnly`: a field no profile may override, so the
/// override, its `diff` and `ScrollGestureField` leave it out.
@Suite("Scroll gesture override parity")
struct ScrollGestureConfigParityTests {
    /// The base's fields no profile overrides (#1873 ▸ Ruling
    /// 2026-11-16: the step length is Lua-only).
    private static let globalOnly: Set<String> = ["stepLength"]

    private func labels(_ value: Any) -> [String] {
        Mirror(reflecting: value).children.compactMap(\.label)
    }

    private var overridable: [String] {
        labels(ScrollGestureBase.defaults).filter {
            !Self.globalOnly.contains($0)
        }
    }

    @Test("the override names every overridable field, and only those")
    func fieldsMirror() {
        let base = labels(ScrollGestureBase.defaults)
        #expect(Self.globalOnly.isSubset(of: base))
        #expect(!overridable.isEmpty)
        #expect(overridable == labels(ScrollGestureOverride()))
    }

    /// A resolve keeps a global-only field the base's, whatever the
    /// override says.
    @Test("a resolve keeps the global-only fields")
    func resolveKeepsGlobalOnly() {
        var base = ScrollGestureBase.defaults
        base.stepLength = 25
        let resolved = ScrollGestureOverride(longSwipes: false)
            .resolved(onto: base)
        #expect(resolved.stepLength == 25)
    }

    /// Every field differs from the base, so a resolve or a diff
    /// that forgets one reds on it.
    @Test("resolve and diff carry every field")
    func resolveAndDiffCarryEveryField() {
        let base = ScrollGestureBase.defaults
        let edited = ScrollGestureBase(
            naturalTrackpad: .off,
            naturalMouse: .off,
            longSwipes: false,
            stepLength: base.stepLength
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
            naturalTrackpad: .off,
            naturalMouse: .off,
            longSwipes: false,
            stepLength: base.stepLength
        )
        #expect(ScrollGestureField.allCases.count == overridable.count)
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
            naturalTrackpad: .off,
            naturalMouse: .off,
            longSwipes: false,
            stepLength: 25
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
