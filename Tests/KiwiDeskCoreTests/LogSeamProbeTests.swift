import Foundation
import Testing

@testable import KiwiDeskCore

/// Sends a line through every `onLog` seam **found on the live
/// object graph** and asserts it comes out of `KiwiCore.onLog`
/// (#625).
///
/// This closes the three limits `LogSeamWiringTests` documents and
/// no source scan can reach. That suite reads text: it proves a
/// seam-owning *type* appears on the left of an assignment in
/// bootstrap. This one reads final runtime state, which answers a
/// different and stronger question — *what is this seam now, and
/// where does its line actually go*:
///
/// 1. **Instance-keyed, not type-keyed.** Two instances of one
///    seam-owning type with only one wired passes the source
///    scan. Here each instance is probed on its own, so the
///    unwired one is caught however many of its siblings are fine.
/// 2. **Routing, not assignment.** `socket.onLog = { _ in }` in
///    bootstrap satisfies a source scan completely. Here the line
///    has to arrive.
/// 3. **Assigned, not assigned exactly once.** A source scan
///    counts assignments in text and has no notion of
///    last-writer-wins; a seam wired correctly in the group and
///    then clobbered by a stale duplicate elsewhere is dead with
///    the scan green. That shape is reachable by silent
///    auto-merge — two assignments far enough apart in
///    `KiwiCore+Bootstrap` merge without a conflict. Probing sees
///    only whichever assignment won, so the clobber reds no
///    matter how many times the seam was assigned. A *harmless*
///    duplicate (the same closure twice) stays green, which is
///    correct: it routes.
///
/// Both suites stay. Neither subsumes the other — this one cannot
/// see a seam the walk cannot **reach** from the core root —
/// which is weaker than "a type never instantiated under
/// `makeTestCore`", and worth stating exactly: a seam owner that
/// is constructed but sits behind a computed accessor, a static,
/// an unforced `lazy var` or (before the `superclassMirror`
/// traversal) a base-class property is live and still invisible.
/// `KiwiCore.lua` is the standing example of the instantiation
/// case — nil under `makeTestCore`, because no config load runs,
/// so a seam there would be scan-visible and probe-invisible.
/// The source scan reads declarations and is indifferent to all
/// of it, which is the axis the two guards actually divide on.
///
/// Discovery, the walk's termination argument and the reason the
/// probe call goes through a protocol rather than a `Mirror`-boxed
/// closure are in `LogSeamDiscovery.swift`.
@Suite("Log-seam runtime probe")
@MainActor
struct LogSeamProbeTests {
    @Test("Every seam on the live graph reaches the sink")
    func everyDiscoveredSeamRoutesToTheSink() {
        let core = makeTestCore()
        var captured: [String] = []
        core.onLog = { captured.append($0) }

        let walk = SeamWalk.over(core)

        // Capped: hitting the depth backstop gaps once per child
        // of the node that hit it, so an uncapped join is dozens
        // of near-identical clauses and the reader has to hunt
        // for the one fact — which node, and how deep.
        #expect(
            walk.gaps.isEmpty,
            Comment(
                rawValue: "the walk could not complete "
                    + "(\(walk.gaps.count) gap(s), first 3): "
                    + walk.gaps.prefix(3).joined(separator: "; ")
            )
        )
        #expect(
            walk.unconformed.isEmpty,
            Comment(
                rawValue: "\(walk.unconformed.joined(separator: "; ")) "
                    + "declares a `var onLog` seam but is not "
                    + "conformed to `LogSeamOwner`, so this guard "
                    + "cannot probe it. Add the conformance in "
                    + "`LogSeamDiscovery.swift` — and note the "
                    + "protocol is `@MainActor`, so a nonisolated "
                    + "owner cannot conform as it stands."
            )
        )

        // The canary, and it is an equality rather than a floor
        // on purpose. `!isEmpty` would only catch a walk that
        // collapsed entirely; a walk that reached seven of eight
        // probes seven and asserts [7] == [7], green. Reachability
        // is this guard's one fail-open direction — see
        // `SeamRegister`, which owns the argument and the list.
        let reached = Set(
            walk.seams.map { "\(type(of: $0.owner))" }
        )
        #expect(
            reached == SeamRegister.reachable,
            Comment(
                rawValue: "the walk no longer reaches "
                    + SeamRegister.reachable.subtracting(reached)
                    .sorted().joined(separator: ", ")
                    + " on a live KiwiCore"
                    + (reached.subtracting(SeamRegister.reachable)
                        .isEmpty
                        ? ""
                        : ", and newly reaches "
                            + reached.subtracting(
                                SeamRegister.reachable
                            ).sorted().joined(separator: ", "))
                    + ". A seam owner leaves the graph silently "
                    + "when it moves behind a computed accessor, "
                    + "a static, an unforced `lazy var` or a "
                    + "superclass property — the seam is then "
                    + "unprobed with every guard green. Restore "
                    + "the stored reference, or record it in "
                    + "`SeamRegister.unreachable` with its reason."
            )
        )

        var sent: [String] = []
        for seam in walk.seams {
            let line = "probe:\(seam.path)"
            sent.append(line)
            seam.owner.onLog(line)
        }

        // Set equality both ways. A dropped line is missing from
        // `captured`; a rewritten or duplicated one is an extra.
        // Both differences are reported — naming only the missing
        // half left the rewrite case reding with an empty list
        // and a stated cause that was not the cause. Sorted
        // because the walk order is the graph's, not something
        // worth pinning.
        //
        // Exact equality does forbid a seam whose body transforms
        // the line (`{ core.onLog("socket: " + $0) }`), which
        // would route correctly. That is deliberate — the seams
        // share one forwarding closure, and the wiring site says
        // why — but it is the assertion to revisit first if a
        // prefixing seam is ever wanted.
        let missing = Set(sent).subtracting(captured)
        let unexpected = Set(captured).subtracting(sent)
        #expect(
            captured.sorted() == sent.sorted(),
            Comment(
                rawValue: "seam routing did not round-trip. "
                    + "Never arrived at `KiwiCore.onLog`: "
                    + "[\(missing.sorted().joined(separator: ", "))]"
                    + " — a seam assigned to a body that drops the "
                    + "line, or clobbered by a later assignment. "
                    + "Arrived unbidden: "
                    + "[\(unexpected.sorted().joined(separator: ", "))]"
                    + " — a seam that rewrites the line, or a "
                    + "second path into the sink."
            )
        )
    }
}
