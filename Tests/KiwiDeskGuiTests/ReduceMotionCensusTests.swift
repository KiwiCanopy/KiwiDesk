import Foundation
import Testing

/// **A census of the ways to start motion is only as good as
/// its own completeness** (#1069). `ReduceMotionGateTests`
/// holds every `withAnimation` and `.animation(_:value:)` to
/// its Reduce Motion gate; this holds the spellings NOTHING
/// there scans at zero occurrences, so the first one to arrive
/// reds rather than shipping unwatched.
///
/// Split from that suite for size (AGENTS.md §2.1), and the
/// seam is the honest one: the two clauses share the walk in
/// `SourceScan+CallSites` and nothing else.
@Suite("Reduce Motion spelling census (#1069)")
struct ReduceMotionCensusTests {
    /// Ways to start motion that NOTHING here scans, held at
    /// zero occurrences (`Sources/KiwiDesk` carries none today).
    ///
    /// A census with no check on its own completeness is the
    /// #1069 failure one level up: `entryPoints` says a new
    /// spelling joins it, and nothing made that happen. The
    /// concrete cost is small and total — one
    /// `.transaction { $0.animation = LayoutSchematic.damping }`
    /// in `LayoutSchematicView`, the shared host of all seven
    /// schematics, injects full motion into every subtree for a
    /// Reduce Motion user, and no child gate is in the way: the
    /// schematics' own chains cover named values only, so
    /// anything they do not name takes the injected animation
    /// (guard-prover, #1069).
    ///
    /// So this fails SHUT rather than tracking the tree. An
    /// entry firing is not a defect in itself — it means a
    /// spelling arrived, and the author owes one of three
    /// dispositions: gate the site and move the needle into
    /// `entryPoints`; narrow the needle; or, where the site
    /// genuinely starts no motion, rule it in `ruled`. Dropping
    /// the entry is the one that is almost never right, since it
    /// un-watches the motion-starting use along with whatever
    /// fired.
    ///
    /// **It fires without motion in three classes**, all
    /// stated because each costs a diagnosis rather than a
    /// defect.
    ///
    /// An ordinary dotted call that merely SHARES a needle's
    /// name reds — `self.animator()`, `Self.animation(for:)` —
    /// because a dot-prefixed needle takes no leading boundary.
    /// `SourceScan.needsBoundary` carries why that trade is the
    /// right way round.
    ///
    /// A SUPPRESSION spelling reds like a starting one:
    /// `withTransaction(Transaction(animation: nil))`,
    /// `CATransaction.setDisableActions(true)` and
    /// `.contentTransition(.identity)` are how motion is turned
    /// OFF and wear the same shape, so nothing here can tell
    /// them apart — the site still wants the ruling.
    ///
    /// And a needle inside a STRING LITERAL reds, because
    /// `SourceScan.stripComments` removes comments and copies
    /// literals verbatim, deliberately (its own docstring says
    /// what a literal-blind stripper cost). Measured, this is
    /// narrower than it sounds: a type needle fires on any
    /// quoted mention, while a call needle fires only where the
    /// prose happens to carry the call shape too — a literal
    /// `"no .transaction, no CATransaction"` reds for the type
    /// and not for the call (guard-prover).
    ///
    /// **Scope: `Sources/KiwiDesk`**, so a green here says the
    /// GUI tree honours the setting, NOT that the app's chrome
    /// does — `.claude/rules/gui.md` ▸ the Reduce Motion gate
    /// rules what that leaves to Core and what it does not.
    ///
    /// Call spellings, matched through `callSites` — the same
    /// whitespace-tolerant walk the gate clause uses, and NOT a
    /// `contains`. An earlier cut narrowed these to
    /// `symbolEffect(` and friends to stop
    /// `.symbolEffectsRemoved()` firing, which bought that one
    /// case and re-opened the fail-open `callSites`' own
    /// docstring records: `.symbolEffect (.bounce, …)` compiles,
    /// ships full motion, and an adjacent-paren needle cannot
    /// see it at all (guard-prover). The walk gets both — it
    /// skips the whitespace AND refuses the longer identifier,
    /// `.symbolEffectsRemoved()` failing because the character
    /// after the skip is a letter rather than a paren.
    ///
    /// A dot-prefixed needle takes its leading boundary from
    /// the `.` alone (`SourceScan.needsBoundary`), and that
    /// exemption is load-bearing rather than tidy: the
    /// character before `.animator` is the last one of the
    /// RECEIVER, so boundary-checking it refuses
    /// `view.animator()` — the spelling every real site uses —
    /// and leaves only chain-broken calls. It cost the gate
    /// clause its main shape for one commit, invisibly, because
    /// the site counts do not move (guard-prover).
    private static let uncensusedCalls = [
        "withTransaction", ".transaction", "phaseAnimator",
        "keyframeAnimator", "symbolEffect", "contentTransition",
        ".animator", "TimelineView",
    ]

    /// Type spellings, where the bare mention is the signal:
    /// constructing one of these is starting an animation.
    /// `TimelineView` is deliberately NOT here: constructing
    /// one is a call, so the call list's paren requirement also
    /// refuses `TimelineViewModel`, which a bare mention would
    /// fire on.
    private static let uncensusedTypes = [
        "NSAnimation", "CATransaction", "CATransition",
        "CABasicAnimation", "CAKeyframeAnimation",
        "CASpringAnimation", "CAAnimationGroup",
    ]

    /// Sites ruled to keep an uncensused spelling, keyed
    /// `File.swift: spelling`, each entry naming the ruling —
    /// the one copy of who is exempt, the shape every sibling
    /// scan guard in `gui.md` carries.
    ///
    /// It exists because two of the false-fire classes above fit
    /// NEITHER other disposition (code review, #1069): a
    /// suppression spelling and a shared-name dotted call start
    /// no motion and cannot be narrowed away, so without a seam
    /// the only escape left is deleting a needle — which
    /// silently un-watches a whole spelling, and is how a census
    /// guard dies. Empty by design; an entry is a ruling, not a
    /// silencer.
    private static let ruled: [String: String] = [:]

    @Test("No uncensused way to start motion ships")
    func everyMotionSpellingIsCensused() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var found: [String] = []
        var scanned = 0
        for file in try SourceScan.swiftSources(under: root) {
            scanned += 1
            let source = try SourceScan.strippedSource(at: file)
            let text = Array(source)
            // `contains` first, then the walk: the walk is
            // strictly narrower, so the fast path can only skip
            // files that had no match to find.
            for spelling in Self.uncensusedCalls
            where source.contains(spelling)
                && !SourceScan.callSites(
                    in: text,
                    for: spelling,
                    closureCounts: true
                ).isEmpty
            {
                Self.record(spelling, in: file, into: &found)
            }
            for spelling in Self.uncensusedTypes
            where source.contains(spelling)
                && SourceScan.mentions(spelling, in: text)
            {
                Self.record(spelling, in: file, into: &found)
            }
        }
        // A clause whose expected result is zero matches passes
        // for having scanned NOTHING, in a millisecond, and its
        // sibling's floor does not stand in — each expresses its
        // own root (guard-prover). A FLOOR against a tree of
        // hundreds, not the live count, which every added file
        // moves (tests.md ▸ a drawn VALUE).
        #expect(scanned >= 100, "scanned \(scanned) files")
        #expect(
            found.isEmpty,
            """
            starts motion with no needle watching it — gate the \
            site and move the spelling into entryPoints, or \
            narrow the needle, or rule it in `ruled`. Dropping \
            the entry un-watches the motion-starting use with \
            it: \(found)
            """
        )
        #expect(
            Self.ruled.keys.allSatisfy(Self.namesAWatchedSpelling),
            "a ruling names a spelling no needle watches"
        )
    }

    /// One find, unless a ruling covers it.
    private static func record(
        _ spelling: String,
        in file: URL,
        into found: inout [String]
    ) {
        let key = "\(file.lastPathComponent): \(spelling)"
        guard ruled[key] == nil else { return }
        found.append(key)
    }

    /// A ruling for a spelling no needle carries watches
    /// nothing, and reads as coverage this has never had.
    private static func namesAWatchedSpelling(_ key: String)
        -> Bool
    {
        let spelling =
            key.split(separator: " ").last
            .map(String.init) ?? ""
        return uncensusedCalls.contains(spelling)
            || uncensusedTypes.contains(spelling)
    }
}
