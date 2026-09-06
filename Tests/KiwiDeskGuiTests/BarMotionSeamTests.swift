import Foundation
import Testing

/// **Core starts motion in the files that gate it** (#1078).
///
/// `ReduceMotionGateTests` holds `Sources/KiwiDesk` per call, in
/// the argument, because a SwiftUI animation carries one. An
/// AppKit frame write does not — `view.animator().frame = f` has
/// nothing at the call for a scan to read — so Core takes the
/// other shape tests.md sanctions: one home per subsystem,
/// routed through, applied exactly once.
///
/// **Scope is `Sources/KiwiDeskCore`, whole**, and that is the
/// second cut. The first derived the roots from `bars.md`'s
/// `paths:` front matter, which was strictly weaker in both
/// directions: a path line deleted there un-guarded a file
/// silently (guard-prover), and a bar surface landing in a
/// directory that front matter does not name — `bars.md` calls
/// #1229's overview panel the next one — was never scanned at
/// all. Measured 2026-09-06, every needle below occurs in
/// exactly four files Core-wide, so scanning all of it costs one
/// walk and closes both holes; `allowed` carries the three that
/// are not `BarMotion`.
@Suite("Core motion routing (#1078)")
struct BarMotionSeamTests {
    /// The file the bars' motion lives in.
    private static let home = "BarMotion.swift"

    /// Ways to start AppKit or Core Animation motion. Type
    /// spellings, where constructing one IS starting an
    /// animation, plus the property-style
    /// `allowsImplicitAnimation`; `NSAnimation` carries
    /// `NSAnimationContext` too, since `mentions` takes no
    /// trailing boundary.
    ///
    /// `CATransaction` is deliberately absent and
    /// `setAnimationDuration` — its one motion-starting member —
    /// stands in for it. The bare type is how motion is turned
    /// OFF (`begin` / `setDisableActions` / `commit`), so
    /// watching it would need a permanent exemption for the
    /// files that suppress, and a permanent exemption also
    /// passes the next real starter there.
    private static let starters = [
        "NSAnimation", "NSViewAnimation", "CABasicAnimation",
        "CAKeyframeAnimation", "CASpringAnimation",
        "CAAnimationGroup", "CATransition",
        "allowsImplicitAnimation", "setAnimationDuration",
    ]

    /// The call-shaped starter, which needs the walk rather than
    /// a mention: `.animator` with no paren requirement also
    /// answers for a stored `animator` of our own.
    private static let animatorCall = ".animator"

    /// SwiftUI's starters, held at ZERO in Core rather than
    /// added to `starters`, because the two lists earn different
    /// answers and merging them would give the wrong one. A
    /// SwiftUI animation carries an argument, so it takes
    /// `ReduceMotionGateTests`' per-call gate — NOT a route
    /// through a `BarMotion`, which is what a `starters` entry
    /// would demand. So the first one to land in Core reds here
    /// and its author widens that suite's root instead.
    private static let swiftUIStarters = [
        "withAnimation", ".animation", ".transaction",
        "phaseAnimator", "keyframeAnimator", "symbolEffect",
        "contentTransition",
    ]

    /// Files that start motion outside `BarMotion`, each naming
    /// its ruling — the one copy of who is exempt.
    ///
    /// The border cues are here because they already stand down
    /// and converting them would remove no defect (§2.4). What
    /// this map does NOT say is that they are guarded: an entry
    /// exempts the whole file, so a SECOND ungated starter added
    /// to one of these three ships green. That is the standing
    /// position `.claude/rules/borders.md` ▸ a cue's animation
    /// names its Reduce Motion read at its site states as an
    /// obligation, because no guard reaches it. What the map
    /// still buys is the FOURTH file: a new Core surface that
    /// animates reds here until someone rules it.
    private static let allowed = [
        "StickyMarkOverlay.swift":
            "gates at its own site; borders.md owns it",
        "StickyMarkPlate.swift":
            "animates only under StickyMarkOverlay's gate",
        "SizeLimitOverlay.swift":
            "gates at its own site; borders.md owns it",
    ]

    /// Every member of the home file, paired with what its body
    /// must name. **The census is the fail-shut half**: a member
    /// added to `BarMotion` reds until it is written down here,
    /// which is what a hand-listed case list could not do — the
    /// routing clause exempts the home file by design, so a
    /// fourth ungated wrapper was invisible to every test in
    /// both suites (guard-prover).
    ///
    /// An empty list claims the member starts no motion, and the
    /// clause refuses that claim for one that does — so a new
    /// starter cannot be admitted quietly, only with the gate it
    /// names written beside it.
    ///
    /// It lists the members that OPEN A BODY, which is what
    /// `memberBodies` returns: `slide` is a stored `let` and is
    /// deliberately absent. That is the walker's stated residue
    /// arriving here — a stored property whose initializer is a
    /// closure could start motion out of this clause's reach —
    /// and it is why `motionHasOneHome` scans the file's whole
    /// text rather than only its members.
    private static let members: [String: [String]] = [
        "isReduced": [],
        "runLayout": ["duration(", "isReduced"],
        "duration": [],
        "setFrame": ["travels(", "isReduced"],
        "travels": [],
        "springSweep": ["springAnimation(", "isReduced"],
        "springAnimation": ["reduceMotion"],
    ]

    private static var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    /// **Residue, stated because it fails OPEN.** Core Animation
    /// starts motion with no spelling at all: a bare write to a
    /// layer property (`layer?.opacity = …`, `strokeEnd = …`)
    /// runs the layer's implicit action over CA's default
    /// duration, and no needle can see it — probed green
    /// (guard-prover). It is not hypothetical, which is why it
    /// is written here: `SpaceBarItemView+DragDrop`'s
    /// `strokeEnd = 1` was exactly that, ungated and racing the
    /// animation added beside it, until a review round moved it
    /// inside the disabled-actions transaction. So a layer write
    /// goes inside one, and this clause is not what tells you
    /// when you forgot. Contrived but legal beside it:
    /// `let proxy = view.animator` detaches the paren
    /// `.animator` requires, and also passes.
    @Test("Core motion starts only where it is gated")
    func motionHasOneHome() throws {
        var strays: [String] = []
        var hits: Set<String> = []
        var scanned = 0
        for file in try SourceScan.swiftSources(
            under: Self.coreRoot
        ) {
            scanned += 1
            let name = file.lastPathComponent
            let source = try SourceScan.strippedSource(at: file)
            let text = Array(source)
            var found: [String] = []
            for spelling in Self.starters
            where source.contains(spelling)
                && SourceScan.mentions(spelling, in: text)
            {
                found.append(spelling)
            }
            if !SourceScan.callSites(
                in: text,
                for: Self.animatorCall
            ).isEmpty {
                found.append(Self.animatorCall)
            }
            guard !found.isEmpty else { continue }
            hits.insert(name)
            guard name != Self.home, Self.allowed[name] == nil
            else { continue }
            strays.append(
                "\(name): \(found.joined(separator: ", "))"
            )
        }
        // A clause whose expected result is zero matches passes
        // for having scanned nothing. A FLOOR against a tree of
        // hundreds, not the live count, which every added Core
        // file moves (tests.md ▸ a drawn VALUE).
        #expect(scanned >= 200, "scanned \(scanned) files")
        // And the needles must still MATCH: the home file
        // carries them, so a spelling that stops matching reds
        // here instead of emptying the clause above in silence.
        #expect(
            hits.contains(Self.home),
            "\(Self.home) no longer matches any starter"
        )
        #expect(
            strays.isEmpty,
            """
            starts motion outside \(Self.home) — route it \
            through a gated home, or rule it in `allowed`: \
            \(strays)
            """
        )
        // Every ruling was CONSUMED. A ruling that outlives its
        // site is silent and still silencing, so the next real
        // starter at that file ships green too.
        #expect(
            Self.allowed.keys.allSatisfy(hits.contains),
            "a ruling fires on nothing: \(Self.allowed.keys)"
        )
    }

    @Test("No SwiftUI starter ships unscanned in Core")
    func noSwiftUIStarterArrives() throws {
        var found: [String] = []
        var scanned = 0
        for file in try SourceScan.swiftSources(
            under: Self.coreRoot
        ) {
            scanned += 1
            let source = try SourceScan.strippedSource(at: file)
            let text = Array(source)
            for spelling in Self.swiftUIStarters
            where source.contains(spelling)
                && !SourceScan.callSites(
                    in: text,
                    for: spelling,
                    closureCounts: true
                ).isEmpty
            {
                found.append(
                    "\(file.lastPathComponent): \(spelling)"
                )
            }
        }
        // Its OWN floor, not the sibling's: borrowed non-vacuity
        // dies the day the clause that lends it is split out or
        // renamed (guard-prover).
        #expect(scanned >= 200, "scanned \(scanned) files")
        #expect(
            found.isEmpty,
            """
            a SwiftUI surface arrived in Core: gate it per call \
            the way `Sources/KiwiDesk` does and widen \
            ReduceMotionGateTests' root to reach it, rather than \
            routing it through BarMotion: \(found)
            """
        )
    }

    /// The home file's members are exactly the censused ones,
    /// each naming its own gate, and no member that starts
    /// motion is censused as starting none.
    ///
    /// Read through `SourceScan.memberBodies`, which walks `var`
    /// and `let` beside `func` and returns overloads separately
    /// — `BarMotion` spells two of its own members as
    /// properties, and a name-keyed `func`-only walk was blind
    /// to both shapes (code review).
    @Test("Every member of BarMotion is censused and gated")
    func everyMemberIsCensused() throws {
        let file = Self.coreRoot
            .appendingPathComponent("Bar/\(Self.home)")
        let source = try SourceScan.strippedSource(at: file)
        let members = SourceScan.memberBodies(in: source)
        let names = members.map(\.declaration)
        #expect(
            Set(names) == Set(Self.members.keys),
            """
            BarMotion's members and the census disagree — a \
            member added here owes an entry naming the gate it \
            reaches: \
            \(Set(names).symmetricDifference(Self.members.keys))
            """
        )
        #expect(
            names.count == Set(names).count,
            "an overload shares a census entry: \(names)"
        )
        for (name, body) in members {
            guard let needles = Self.members[name] else {
                continue
            }
            for needle in needles {
                #expect(
                    body.contains(needle),
                    "\(name) does not name \(needle)"
                )
            }
            guard needles.isEmpty, Self.startsMotion(body) else {
                continue
            }
            Issue.record(
                "\(name) starts motion, censused as gateless"
            )
        }
    }

    /// Whether a member's body reaches a motion starter.
    private static func startsMotion(_ body: String) -> Bool {
        let text = Array(body)
        if starters.contains(where: {
            body.contains($0) && SourceScan.mentions($0, in: text)
        }) {
            return true
        }
        return !SourceScan.callSites(
            in: text,
            for: animatorCall
        ).isEmpty
    }
}
