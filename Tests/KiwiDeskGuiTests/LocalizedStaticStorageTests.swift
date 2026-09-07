import Foundation
import Testing

/// #1311 — a localized value is COMPUTED per read, never STORED
/// for the life of whatever owns the store.
///
/// The subject is the store's lifetime, not one spelling. A
/// `static let` is a lazily-initialised global: its initialiser
/// runs once, at first touch, and the value is cached for the
/// process. A `lazy var` freezes for as long as its object lives,
/// which is the same thing when that object is a singleton. A
/// language switch rebuilds the whole view tree
/// (`LocaleScopedRoot`) but cannot recompute a stored value, so
/// the label keeps whichever locale was live at that first read —
/// order-dependent, so one build shows a page frozen and its twin
/// correct.
///
/// The clause pins the SHAPE, not the strings: `L()` may not be
/// reachable while a stored declaration is being INITIALISED,
/// directly or through a helper in the same file. Storing a
/// CLOSURE that resolves `L()` later is the sanctioned shape — it
/// is how `NavCommand` carries its labels
/// (`NavCommand.resolvedLabel`), and `deferredIntroducers` is the
/// one list of the spellings that defer.
@Suite("A localized value is never stored")
struct LocalizedStaticStorageTests {
    /// The trees scanned, each of which must yield files — a
    /// renamed tree or a moved test file otherwise leaves this
    /// suite green having read nothing.
    static let roots = ["Sources/KiwiDesk", "Sources/KiwiDeskCore"]

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
    ///
    /// What it TRADES, both fail-open and both latent: the three
    /// labels are blanked in every file of both trees, so a type
    /// other than `NavCommand` gaining an eagerly-applied `help:`
    /// closure is exempted silently; and `return { … }()` reads
    /// as deferred while running at once. Today `help: {` is
    /// spelled only in `KeybindingCatalog+Resize` and no
    /// immediately-invoked `return` closure exists in either
    /// tree.
    static let deferredIntroducers = [
        "displayLabel:", "help:", "unavailable:", "return",
    ]

    /// Two further residues, both fail-open, both inherited
    /// rather than introduced here (`guard-prover`, #1311):
    /// helper reach stops at the FILE, so a stored value fed by
    /// another file's localized helper is invisible; and
    /// `SourceScan.blankingCommentsAndLiterals` toggles on plain
    /// `"` alone, so a literal carrying an odd number of them
    /// blanks the rest of its file — measured today in
    /// `ServiceManager.swift`, whose plist heredoc hides 264 of
    /// its 283 lines from every guard in that family. The
    /// blanker is shared, so hardening it is its own change
    /// (#1320).
    ///
    /// Survivors, keyed by the string a failure prints, each
    /// naming what makes it safe.
    ///
    /// EMPTY, and that is the claim. An entry added here says a
    /// reader judged one safe and why — it is not a place to
    /// silence a red.
    static let allowed: [String: String] = [:]

    @Test("no stored declaration resolves L() at initialisation")
    func localizedValuesAreComputed() throws {
        let root = SourceScan.repoRoot(from: "\(#filePath)")
        var offenders: [String] = []
        for tree in Self.roots {
            let files = try SourceScan.swiftSources(
                under: root.appendingPathComponent(tree)
            )
            #expect(
                !files.isEmpty,
                """
                \(tree) yielded no Swift files — this scan reads \
                nothing and would pass for that reason. Fix the \
                root, do not delete the check.
                """
            )
            for file in files {
                offenders += try frozen(in: file, tree: tree)
            }
        }
        #expect(
            offenders.isEmpty,
            """
            These declarations resolve `L()` once, at first \
            touch, and keep that locale for as long as the store \
            lives (#1311) — give each one a COMPUTED body \
            (`var x: T { … }`, no `=`), or store a closure the \
            reader resolves:
            \(offenders.joined(separator: "\n"))
            """
        )
    }
}
