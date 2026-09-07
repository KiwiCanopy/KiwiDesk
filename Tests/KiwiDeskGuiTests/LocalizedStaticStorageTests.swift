import Foundation
import Testing

/// #1311 — a localized value is COMPUTED per read, never stored
/// in a `static let`.
///
/// A `static let` is a lazily-initialised global: its initialiser
/// runs once, at first touch, and the value is cached for the
/// life of the process. A language switch rebuilds the whole view
/// tree (`LocaleScopedRoot`) but cannot recompute a stored value,
/// so the label keeps whichever locale was live at that first
/// read — order-dependent, so the same build shows one page
/// frozen and its twin correct.
///
/// The clause pins the SHAPE, not the strings: `L()` may not be
/// reachable while a `static let` is being INITIALISED, directly
/// or through a helper in the same file. Storing a CLOSURE that
/// calls `L()` later is the sanctioned shape — it is how
/// `NavCommand` carries its labels (`NavCommand.resolvedLabel`),
/// and `deferredIntroducers` is the one list of the spellings
/// that defer.
@Suite("A localized value is never stored in a static let")
struct LocalizedStaticStorageTests {
    /// The spellings after which a `{ … }` run is STORED rather
    /// than run at initialisation: `NavCommand`'s three label
    /// parameters, and a helper returning a label closure.
    ///
    /// Deliberately a closed list rather than "any closure": a
    /// trailing `map { … }` and an immediately-invoked
    /// `{ … }()` both run eagerly, and `AppBarOptions.edge` —
    /// the declaration #1311 was reported against — reached
    /// `L()` through exactly such a `map`. Exempting braces as a
    /// kind would have left the reported defect green.
    static let deferredIntroducers = [
        "displayLabel:", "help:", "unavailable:", "return",
    ]

    /// Survivors, each naming what makes it safe.
    ///
    /// EMPTY, and that is the claim: nothing in either tree
    /// stores a localized value today. An entry added here says a
    /// reader judged one safe and why — it is not a place to
    /// silence a red.
    static let allowed: [String: String] = [:]

    @Test("no static let resolves L() at initialisation")
    func localizedValuesAreComputed() throws {
        let root = SourceScan.repoRoot(from: "\(#filePath)")
        var offenders: [String] = []
        for tree in ["Sources/KiwiDesk", "Sources/KiwiDeskCore"] {
            let directory = root.appendingPathComponent(tree)
            for file in try SourceScan.swiftSources(
                under: directory
            ) {
                offenders += try frozen(in: file, tree: tree)
            }
        }
        #expect(
            offenders.isEmpty,
            """
            These `static let`s resolve `L()` once, at first \
            touch, and keep that locale for the life of the \
            process (#1311) — make each one a computed \
            `static var`, or store a closure the reader \
            resolves:
            \(offenders.joined(separator: "\n"))
            """
        )
    }
}
