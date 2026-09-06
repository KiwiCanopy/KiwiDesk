import Foundation
import Testing

/// **The bars start motion in one file, and that file gates it**
/// (#1078).
///
/// `ReduceMotionGateTests` holds `Sources/KiwiDesk` per call, in
/// the argument, because a SwiftUI animation carries one. Core
/// draws the bars through AppKit and Core Animation, where the
/// gate has nowhere to sit in the call — `view.animator().frame
/// = f` takes no animation argument at all — so the shape here
/// is the other one tests.md sanctions: one home, routed through
/// the seam, applied exactly once.
///
/// Which makes this suite the half `BarMotionTests` cannot be.
/// That one proves the decisions; a decision proved correct in a
/// file nothing calls gates nothing, and the way this regresses
/// is a new bar surface animating beside `BarMotion` rather than
/// through it — exactly how the bars came to be the one Core
/// tree reading no setting at all while the border cues beside
/// them read it at four sites.
///
/// **Scope: `Sources/KiwiDeskCore/Bar`.** A green here says the
/// bars honour the setting, not that Core does — `Borders/`
/// gates at its own sites and is guarded by nothing, which
/// `.claude/rules/gui.md` ▸ the Reduce Motion gate states.
@Suite("Bar Reduce Motion routing (#1078)")
struct BarMotionSeamTests {
    /// The file every motion-starting call under `Bar/` lives
    /// in.
    private static let home = "BarMotion.swift"

    /// Ways to start AppKit or Core Animation motion. Type
    /// spellings, where constructing one IS starting an
    /// animation, plus the property-style `allowsImplicitAnimation`;
    /// `NSAnimation` carries `NSAnimationContext` too, since
    /// `mentions` takes no trailing boundary.
    ///
    /// `CATransaction` is deliberately absent and
    /// `setAnimationDuration` — its one motion-starting member —
    /// stands in for it. The bare type is how motion is turned
    /// OFF (`begin` / `setDisableActions` / `commit`, which the
    /// drop ring uses three times), so watching it would need a
    /// permanent exemption for those files, and a permanent
    /// exemption also passes the next real starter there.
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

    /// Sites ruled to start motion outside `BarMotion`, keyed
    /// `File.swift: spelling`, each naming its ruling. Empty by
    /// design — an entry is a ruling that some bar motion must
    /// run for a user who asked for less, or that a spelling
    /// starts none — and one that stops firing is deleted, which
    /// the consumed clause below makes it red to forget.
    private static let allowed: [String: String] = [:]

    private static var barRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore/Bar")
    }

    @Test("Bar motion starts only in BarMotion")
    func motionHasOneHome() throws {
        var strays: [String] = []
        var hits: Set<String> = []
        var scanned = 0
        for file in try SourceScan.swiftSources(under: Self.barRoot) {
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
        // for having scanned nothing. A FLOOR against a
        // forty-file directory, not the live count, which every
        // added bar file moves (tests.md ▸ a drawn VALUE).
        #expect(scanned >= 20, "scanned \(scanned) files")
        // And the needles must still MATCH: the home file
        // carries three of them, so a spelling that stops
        // matching reds here instead of emptying the clause
        // above in silence.
        for spelling in ["NSAnimation", "CABasicAnimation", ".animator"] {
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

    /// The wrappers CONSULT the decisions and feed them the live
    /// setting. Without this the abstraction is the one
    /// `.claude/rules/gui.md` warns against: deleting the gate
    /// inside a shared helper ungates every caller at once, and
    /// the clause above stays green because the motion never
    /// moved out of its home.
    @Test("The two wrappers name their gate")
    func wrappersConsultTheGate() throws {
        let cases = [
            ("setFrame", ["travels(", "isReduced"]),
            ("runLayout", ["duration(reduceMotion:", "isReduced"]),
        ]
        for (function, needles) in cases {
            let body = try SourceScan.functionBody(
                of: function,
                in: Self.home,
                under: "Bar"
            )
            for needle in needles {
                #expect(
                    body.contains(needle),
                    "\(function) does not name \(needle)"
                )
            }
        }
    }

    /// The one decision a caller passes rather than the wrapper
    /// reading it, so it takes the `ReduceMotionGateTests` shape:
    /// the gate named in the argument.
    @Test("Every springSweep call names its gate")
    func springSweepCallsAreGated() throws {
        var sites = 0
        var ungated: [String] = []
        for file in try SourceScan.swiftSources(under: Self.barRoot)
        where file.lastPathComponent != Self.home {
            let source = try SourceScan.strippedSource(at: file)
            let text = Array(source)
            for site in SourceScan.callSites(
                in: text,
                for: "springSweep"
            ) {
                sites += 1
                guard var cursor = site.paren else { continue }
                let args =
                    SourceScan.balanced(
                        text,
                        from: &cursor,
                        open: "(",
                        close: ")"
                    ) ?? ""
                if !args.contains("reduceMotion") {
                    ungated.append(file.lastPathComponent)
                }
            }
        }
        #expect(sites >= 1, "no springSweep call scanned")
        #expect(ungated.isEmpty, "ungated: \(ungated)")
    }
}
