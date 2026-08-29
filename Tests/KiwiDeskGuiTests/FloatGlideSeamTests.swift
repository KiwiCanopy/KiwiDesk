import Foundation
import Testing

/// The seams #1090 added to the held glide, split from
/// `HoldGlideSeamTests` at §2.1's ceiling rather than after
/// crossing it. That suite owns #1082's two inverted seams
/// (`applyGlideStep`, `startFrames`) and the per-write scope's
/// reader census; this one owns the floating path's commanded
/// base — the seam that retires it, and the routing that decides
/// whether a glide frame writes instantly at all.
///
/// Both guards here are SOURCE SCANS, and both exist because the
/// behaviour they watch is otherwise nearly invisible: dropping
/// the clear has no symptom until one specific press sequence,
/// and dropping the routing has none at all on a screenless
/// runner. Each test's own docstring carries the measurement.
@Suite("Floating glide seams (#1090)")
struct FloatGlideSeamTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )
    private static let productionTrees = [
        root.appendingPathComponent("Sources/KiwiDeskCore"),
        root.appendingPathComponent("Sources/KiwiDesk"),
    ]

    /// The one file allowed to wire either seam — named rather
    /// than described, since a second site is the drift this
    /// counts.
    private static let wiringFile = "KiwiCore+HoldGlide.swift"

    private static func sites(
        of needle: String
    ) throws -> [MachineTouchSite] {
        try productionTrees.flatMap {
            try SourceScan.identifierSites(of: needle, under: $0)
        }
    }

    @Test("Both resize writes route through the one policy")
    func resizeWritesRouteThroughThePolicy() throws {
        // The headless net under
        // `FloatGlideAccumulationTests` ▸ `The same run animated
        // lands in the same place` (guard-prover, 2026-08-29).
        // That test is the only thing in the tree that catches
        // the floating path re-deciding its animation inline
        // instead of taking `resizeWritesAnimated` — measured:
        // with that call site changed back to the raw setting,
        // exactly one assertion in 4223 tests redded, and it is
        // inside an `.enabled(if: NSScreen.main != nil)` test. So
        // on a screenless runner a glide frame would go back to
        // springing, with the whole suite green — and that is the
        // #611 retarget storm the rule file calls a safety
        // property, not a matter of feel.
        //
        // A SHAPE pin, not a value one (tests.md): it holds that
        // each resize write ROUTES through the one policy, never
        // what the policy currently returns. Retuning the policy
        // reds nothing here; re-deciding it beside a call site
        // reds both clauses.
        let routed = try Self.sites(
            of: "animated: resizeWritesAnimated"
        )
        let byFile = Dictionary(
            grouping: routed,
            by: { $0.file.lastPathComponent }
        )
        #expect(
            byFile["KiwiCore+Resize.swift"]?.count == 1,
            """
            the tiled retile must take resizeWritesAnimated; \
            found \(byFile["KiwiCore+Resize.swift"]?.count ?? 0) \
            site(s)
            """
        )
        #expect(
            byFile["KiwiCore+ResizeFloating.swift"]?.count == 1,
            """
            the floating write must take resizeWritesAnimated \
            too (#1090) — found \
            \(byFile["KiwiCore+ResizeFloating.swift"]?.count ?? 0) \
            site(s). A glide frame that springs re-opens the \
            #611 retarget storm.
            """
        )
    }

    @Test("The press-begin seam clears the #1090 base")
    func fireBeginSeamClearsTheFloatingBase() throws {
        // The bound with NO visible symptom when it is dropped:
        // the record outlives the press that wrote it, and a
        // later hold reaching that same float — an arming press
        // on a tiled window plus a focus change mid-hold — bases
        // a glide frame on a frame from an unrelated press.
        //
        // Pinned from both sides like the two seams above, and
        // for the same reason: the inert default is a working
        // no-op. Deleting the wiring is the silent direction, and
        // a SECOND assignment would clear a record the press had
        // already written, costing the arming press its own step.
        //
        // The behavioural half is `FloatGlideAccumulationTests` ▸
        // `A stale record from an earlier press is not read`,
        // which drives that exact sequence; this pins that the
        // clear is reachable at all, from the one seam that fires
        // on every press rather than only on runs that glided.
        let wired = try Self.sites(of: "holdGlide.onFireBegan =")
        #expect(
            wired.count == 1,
            """
            expected exactly one holdGlide.onFireBegan wiring, \
            found \(wired.count): \
            \(wired.map(\.site).joined(separator: ", "))
            """
        )
        #expect(
            wired.allSatisfy {
                $0.file.lastPathComponent == Self.wiringFile
            }
        )
        // The needle carries the RECEIVER so the declaration in
        // `AnimationEngine+CommandedBase` is not counted as a
        // call — the same reason the seam needles carry
        // `holdGlide.`.
        let cleared = try Self.sites(
            of: "animation.clearGlideCommanded()"
        )
        #expect(
            cleared.count == 1,
            """
            expected exactly one clearGlideCommanded() call, \
            found \(cleared.count): \
            \(cleared.map(\.site).joined(separator: ", "))
            """
        )
        #expect(
            cleared.allSatisfy {
                $0.file.lastPathComponent == Self.wiringFile
            },
            """
            the #1090 base must be cleared from the press-begin \
            seam, not beside a call site
            """
        )
    }
}
