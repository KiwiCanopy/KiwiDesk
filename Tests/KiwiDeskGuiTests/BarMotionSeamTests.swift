import Foundation
import Testing

/// **The bars start motion in one file, and that file gates it**
/// (#1078).
///
/// `ReduceMotionGateTests` holds `Sources/KiwiDesk` per call, in
/// the argument, because a SwiftUI animation carries one. An
/// AppKit frame write does not — `view.animator().frame = f` has
/// nothing at the call for a scan to read — so the bars take the
/// other shape tests.md sanctions: one home, routed through the
/// seam, applied exactly once.
///
/// Which makes this suite the half `BarMotionTests` cannot be.
/// That one proves the decisions; a decision proved correct in a
/// file nothing calls gates nothing, and the way this regresses
/// is a new bar surface animating beside `BarMotion` rather than
/// through it — exactly how the bars came to be the one Core
/// tree reading no setting at all while the border cues beside
/// them read it at their own sites.
///
/// **Scope is the bar subsystem as `bars.md` declares it**, read
/// off that file's own `paths:` rather than hand-listed here: a
/// bar animation lands in an `App/KiwiCore+*Bar*.swift` driver
/// as readily as under `Bar/`, which is why that front matter
/// names more than the directory, and a hand copy here would
/// silently scan the wrong tree while its floor stayed green
/// (`ChromeScanRoots` is the same argument one directory over).
/// A green still says the BARS honour the setting, not that Core
/// does — `Borders/` gates at its own sites and is guarded by
/// nothing, which `.claude/rules/borders.md` states.
@Suite("Bar Reduce Motion routing (#1078)")
struct BarMotionSeamTests {
    /// The file every motion-starting call in the subsystem
    /// lives in.
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
    /// OFF (`begin` / `setDisableActions` / `commit`, which the
    /// drop ring uses), so watching it would need a permanent
    /// exemption for those files, and a permanent exemption also
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

    /// SwiftUI's starters, held at ZERO here rather than added
    /// to `starters`, because the two lists earn different
    /// answers and merging them would give the wrong one. The
    /// subsystem is AppKit today; `bars.md` names #1229's
    /// overview panel as the next bar surface, and if it arrives
    /// in SwiftUI its animations carry an argument, so they take
    /// `ReduceMotionGateTests`' per-call gate — NOT a route
    /// through `BarMotion`, which is what a `starters` entry
    /// would demand. So the first one to land reds here and its
    /// author widens that suite's root instead.
    private static let swiftUIStarters = [
        "withAnimation", ".animation", ".transaction",
        "phaseAnimator", "keyframeAnimator", "symbolEffect",
        "contentTransition",
    ]

    /// Sites ruled to start motion outside `BarMotion`, keyed
    /// `File.swift: spelling`, each naming its ruling. Empty by
    /// design — an entry is a ruling that some bar motion must
    /// run for a user who asked for less, or that a spelling
    /// starts none — and one that stops firing is deleted, which
    /// the consumed clause below makes it red to forget.
    private static let allowed: [String: String] = [:]

    /// **Residue, stated because it fails OPEN.** Core Animation
    /// starts motion with no spelling at all: a bare write to a
    /// layer property (`layer?.opacity = …`, `strokeEnd = …`)
    /// runs the layer's implicit action over CA's default
    /// duration, and no needle can see it — probed green
    /// (guard-prover). It is not hypothetical, which is why it
    /// is written here: `SpaceBarItemView+DragDrop`'s
    /// `strokeEnd = 1` was exactly that, ungated and racing the
    /// animation added beside it, until the review round moved
    /// it inside the disabled-actions transaction. So a layer
    /// write under a bar goes inside one, and this clause is not
    /// what tells you when you forgot. Contrived but legal
    /// beside it: `let proxy = view.animator` detaches the paren
    /// `.animator` requires, and also passes.
    @Test("Bar motion starts only in BarMotion")
    func motionHasOneHome() throws {
        var strays: [String] = []
        var hits: Set<String> = []
        var scanned = 0
        for file in try BarScanRoots.sources(from: #filePath) {
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
            for spelling in found {
                let key = "\(name): \(spelling)"
                hits.insert(key)
                guard name != Self.home,
                    Self.allowed[key] == nil
                else { continue }
                strays.append(key)
            }
        }
        // A clause whose expected result is zero matches passes
        // for having scanned nothing. FLOORS, not the live
        // counts, which every added bar file moves (tests.md ▸ a
        // drawn VALUE) — and the root floor is the one that
        // catches a front matter this stopped parsing.
        #expect(scanned >= 20, "scanned \(scanned) files")
        #expect(
            BarScanRoots.paths(from: #filePath).count >= 2,
            "bar scan roots did not parse"
        )
        // And the needles must still MATCH: the home file
        // carries three of them, so a spelling that stops
        // matching reds here instead of emptying the clause
        // above in silence.
        for spelling in [
            "NSAnimation", "CABasicAnimation", ".animator",
        ] {
            #expect(
                hits.contains("\(Self.home): \(spelling)"),
                "\(Self.home) no longer matches \(spelling)"
            )
        }
        #expect(
            strays.isEmpty,
            """
            starts motion outside \(Self.home) — route it \
            through BarMotion, or rule it in `allowed`: \(strays)
            """
        )
        #expect(
            Self.allowed.keys.allSatisfy(hits.contains),
            "a ruling fires on nothing: \(Self.allowed.keys)"
        )
    }

    @Test("No SwiftUI bar surface ships unscanned")
    func noSwiftUIStarterArrives() throws {
        var found: [String] = []
        for file in try BarScanRoots.sources(from: #filePath) {
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
        #expect(
            found.isEmpty,
            """
            a SwiftUI bar surface arrived: gate it per call the \
            way `Sources/KiwiDesk` does and widen \
            ReduceMotionGateTests' root to reach it, rather than \
            routing it through BarMotion: \(found)
            """
        )
    }

    /// Each wrapper CONSULTS its own decision and feeds it the
    /// live setting. Without this the abstraction is the one
    /// `.claude/rules/gui.md` warns against: deleting the gate
    /// inside a shared helper ungates every caller at once, and
    /// the routing clause stays green because the motion never
    /// moved out of its home.
    ///
    /// **Residue, stated because it fails OPEN**, the same shape
    /// `ReduceMotionGateTests.gates` records: this proves the
    /// wrapper NAMES its decision, never that it uses the answer
    /// the right way round — `if !travels(…)` passes. Deciding
    /// that needs types, which a source scan does not have. What
    /// stands in is that each wrapper is one branch over a
    /// decision this suite's sibling asserts, and the device
    /// eye-confirm the gate earns.
    @Test("Each wrapper names its gate")
    func wrappersConsultTheGate() throws {
        let cases = [
            ("runLayout", ["duration(", "isReduced"]),
            ("setFrame", ["travels(", "isReduced"]),
            ("springSweep", ["springAnimation(", "isReduced"]),
        ]
        for (function, needles) in cases {
            let body = try SourceScan.functionBody(
                of: function,
                in: Self.home,
                under: "Bar"
            )
            #expect(!body.isEmpty, "\(function): empty body")
            for needle in needles {
                #expect(
                    body.contains(needle),
                    "\(function) does not name \(needle)"
                )
            }
        }
    }
}
