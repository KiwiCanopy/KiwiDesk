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
/// see a seam on a type that is never instantiated under
/// `makeTestCore`, and the source scan cannot see any of the
/// three above.
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
                    + "`LogSeamDiscovery.swift`."
            )
        )

        // The canary over the collection this test consumes. A
        // walk that reaches nothing leaves `sent` and `captured`
        // both empty, and the routing assertion below then holds
        // vacuously — [] == []. No count is pinned: the set is
        // meant to grow with each new subsystem.
        #expect(
            !walk.seams.isEmpty,
            Comment(
                rawValue: "the walk found no seam at all on a "
                    + "live KiwiCore, so nothing below was probed"
            )
        )

        var sent: [String] = []
        for seam in walk.seams {
            let line = "probe:\(seam.path)"
            sent.append(line)
            seam.owner.onLog(line)
        }

        // Set equality, not prefix or count: a seam wired to a
        // body that drops the line is missing from `captured`, and
        // a seam wired to something that rewrites the line shows
        // up as an unexpected entry. Sorted because the walk order
        // is the graph's, not something worth pinning.
        #expect(
            captured.sorted() == sent.sorted(),
            Comment(
                rawValue: "these seams did not deliver their "
                    + "line to `KiwiCore.onLog`: "
                    + Set(sent).subtracting(captured).sorted()
                    .joined(separator: ", ")
                    + " — a seam that is assigned but wired to a "
                    + "body which drops the line, or clobbered by "
                    + "a later assignment, fails exactly here."
            )
        )
    }
}
