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
            for spelling in BarMotionNeedles.starters
            where source.contains(spelling)
                && SourceScan.mentions(spelling, in: text)
            {
                found.append(spelling)
            }
            if !SourceScan.callSites(
                in: text,
                for: BarMotionNeedles.animatorCall
            ).isEmpty {
                found.append(BarMotionNeedles.animatorCall)
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
        var scanned = 0
        for file in try BarScanRoots.sources(from: #filePath) {
            scanned += 1
            let source = try SourceScan.strippedSource(at: file)
            let text = Array(source)
            for spelling in BarMotionNeedles.swiftUIStarters
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
        // Its OWN floor, not the sibling's: with bars.md's fence
        // broken this passed in 0.001 s having scanned nothing,
        // and borrowed non-vacuity dies the day the clause that
        // lends it is split out or renamed (guard-prover).
        #expect(scanned >= 20, "scanned \(scanned) files")
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

    /// The declared roots reach every file the tree says is bar
    /// code. `BarScanRoots` reads bars.md; this reads the file
    /// system, and the two are only useful together — a line
    /// deleted from that front matter parses cleanly, scans one
    /// file fewer and reds no floor, which guard-prover proved
    /// by un-guarding a live motion starter that way.
    @Test("The declared roots cover the subsystem")
    func coversTheSubsystem() {
        let declared = Set(
            BarScanRoots.paths(from: #filePath).map(\.path)
        )
        let repo = SourceScan.repoRoot(from: #filePath)
        let missing = BarScanRoots.expected(from: #filePath)
            .map { repo.appendingPathComponent($0).path }
            .filter { !declared.contains($0) }
        #expect(
            declared.count >= 2,
            "bar scan roots did not parse"
        )
        #expect(
            missing.isEmpty,
            """
            bar code no declared root reaches — add the path to \
            .claude/rules/bars.md, which is both this guard's \
            root list and how a human is routed to the rule: \
            \(missing)
            """
        )
    }

    /// **Every motion-starting function in the home file is
    /// gated**, the list read off the file rather than written
    /// here. The clause below is hand-listed at three entries,
    /// and `motionHasOneHome` exempts this file by design — so a
    /// FOURTH wrapper with no gate at all was invisible to both
    /// suites, which is this guard's own regression shape one
    /// level in (guard-prover). A function counts as gated if it
    /// names `isReduced` or is HANDED the answer, which is what
    /// a pure decision does.
    @Test("Every motion-starting function in BarMotion is gated")
    func everyStarterInTheHomeIsGated() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Bar/\(Self.home)"
            )
        let source = try SourceScan.strippedSource(at: file)
        let names = BarMotionNeedles.functionNames(in: source)
        var starters = 0
        var ungated: [String] = []
        for name in names {
            let body = try SourceScan.functionBody(
                of: name,
                in: Self.home,
                under: "Bar"
            )
            guard BarMotionNeedles.startsMotion(body) else { continue }
            starters += 1
            let signature = BarMotionNeedles.signature(of: name, in: source)
            guard
                body.contains("isReduced")
                    || signature.contains("reduceMotion")
            else {
                ungated.append(name)
                continue
            }
        }
        #expect(names.count >= 5, "found \(names.count) funcs")
        #expect(starters >= 2, "\(starters) starters found")
        #expect(
            ungated.isEmpty,
            """
            starts motion without reading the setting or being \
            handed it: \(ungated)
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
