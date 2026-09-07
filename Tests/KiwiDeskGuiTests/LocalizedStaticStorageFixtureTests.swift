import Foundation
import Testing

/// What makes `LocalizedStaticStorageTests`' hand-listed
/// registers load-bearing (#1311).
///
/// That suite reads the real trees, so it says nothing about a
/// register that SHRANK: `guard-prover` deleted the `lazy var`
/// row from `storingSpellings` while a live `lazy var` offender
/// sat in the tree, and the suite stayed green. A register
/// nothing derives needs its rows exercised one at a time, which
/// is what this does — over hand-written source, so a row's
/// deletion reds here whatever the tree happens to contain.
///
/// The negative cases matter as much: a widened spelling that
/// started flagging ordinary computed properties, or a blanking
/// rule that stopped exempting `NavCommand`'s stored closures,
/// would make the guard a tax rather than a net.
@Suite("Every stored spelling and walker rule is exercised")
struct LocalizedStaticStorageFixtureTests {
    private static let call = #"L("k", "v")"#

    /// Sources that MUST be flagged, one per register row or
    /// walker rule, named by what would have to break.
    static let frozen: [(String, String)] = [
        (
            "static let",
            """
            enum A {
                static let x = \(call)
            }
            """
        ),
        (
            "static var",
            """
            enum A {
                static var x = \(call)
            }
            """
        ),
        (
            "lazy var",
            """
            final class A {
                lazy var x = \(call)
            }
            """
        ),
        (
            "a global let, behind a modifier",
            """
            @MainActor let x = \(call)
            """
        ),
        (
            "a continuation line ending outside any operator set",
            """
            enum A {
                static let x =
                    Bool.random()
                    ? \(call)
                    : "other"
            }
            """
        ),
        (
            "reach through a same-file helper",
            """
            enum A {
                static let x = label()
                static func label() -> String { \(call) }
            }
            """
        ),
        (
            "reach through an eagerly-applied map",
            """
            enum A {
                static let x = [1].map { _ in label() }
                static func label() -> String { \(call) }
            }
            """
        ),
        (
            "an immediately-invoked initialiser",
            """
            enum A {
                static let x: String = {
                    \(call)
                }()
            }
            """
        ),
    ]

    /// Sources that must NOT be flagged — the shapes the fix
    /// itself recommends, and the one deferral the tree uses.
    static let computed: [(String, String)] = [
        (
            "a computed property, which is the recommended fix",
            """
            enum A {
                static var x: String { \(call) }
            }
            """
        ),
        (
            "a stored closure NavCommand resolves at read",
            """
            enum A {
                static let x = NavCommand(
                    displayLabel: { \(call) }
                )
            }
            """
        ),
        (
            "a local let inside a body",
            """
            enum A {
                static func f() -> String {
                    let x = \(call)
                    return x
                }
            }
            """
        ),
    ]

    @Test("each stored shape is caught", arguments: frozen)
    func storedShapesAreCaught(_ shape: (String, String)) {
        #expect(
            LocalizedStaticStorageTests
                .frozenNames(in: shape.1) == ["x"],
            """
            the scan no longer catches \(shape.0) — a register \
            row or a walker rule was dropped, and the tree scan \
            cannot tell you which (#1311).
            """
        )
    }

    @Test("each deferred shape is left alone", arguments: computed)
    func deferredShapesAreExempt(_ shape: (String, String)) {
        #expect(
            LocalizedStaticStorageTests
                .frozenNames(in: shape.1).isEmpty,
            """
            the scan now flags \(shape.0), which is correct code \
            — the guard has become a tax (#1311).
            """
        )
    }
}
