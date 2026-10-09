import Foundation
import Testing

/// Every writer of a float's stash capture in Core is classified,
/// or it reds (#1177). The seed is the ONE delivery door for a
/// frame nothing else will place (#1352), and its writers have
/// load-bearing relative order — the gather ahead of the strand
/// net, the clamp correcting a capture in place — so a seventh
/// writer that seeds a corner, or seeds after the pass that would
/// deliver it, has nothing to red it but this census.
///
/// The lens, not the list: the scan finds every `seedStash(`
/// spelling under `Sources/KiwiDeskCore` and pins a per-file
/// count with the reason each file may write. It reads the SHAPE
/// — that a file spells the seed N times — never which frame it
/// seeds; `FloatStrandRecoveryTests`, `FloatGatherEntryTests`,
/// `RestoredFrameDebtTests` and `FloatClampPendingCaptureTests`
/// are the consumer nets.
@Suite("Stash seeder census")
struct StashSeederCensusTests {
    /// Files spelling `seedStash(`, each with its reason.
    private let allowed: [String: Int] = [
        // The definition itself.
        "Tiling/TilingEngine+StashRestore.swift": 1,
        // The display-crossing re-anchor (#444).
        "App/KiwiCore+FloatReanchor.swift": 1,
        // The strand net's centred capture (#1352).
        "App/KiwiCore+FloatRecovery.swift": 1,
        // The float placement of a window a move verb files into
        // a floating Space (#1708): a centred, cascaded or
        // remembered frame in the grow bound — never a corner —
        // seeded ahead of the move's own retile, whose #1177
        // gather outranks it by overwriting where it trips. The
        // float verbs' placement of a window on a Space no screen
        // shows (#1518) takes the same gated door, after the
        // verb's retile because only the activation delivers it.
        "App/KiwiCore+FloatPlacement.swift": 1,
        // The entry-into-floating gather (#1177).
        "App/KiwiCore+FloatGather.swift": 1,
        // The clamp correcting a pending capture in place, so
        // the echo consumes it (#1177).
        "App/KiwiCore+FloatClamp.swift": 1,
        // The replay of a parked record, and the late arrival's
        // owed frame (#1352, #1362); and a replayed float's record
        // beside its set, never a corner, so a park ahead of the
        // set's echo keeps it rather than the quit grid's (#1864).
        "App/KiwiCore+Restore.swift": 3,
    ]

    @Test("every seedStash( writer in Core is classified")
    func everyWriterIsClassified() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let prefix = root.path + "/"
        var counts: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let key = String(file.path.dropFirst(prefix.count))
            let source = try SourceScan.strippedSource(at: file)
            let hits = source.occurrences(of: "seedStash(")
            guard hits > 0 else { continue }
            counts[key] = hits
        }
        // Non-vacuity: the scan saw the definition.
        #expect(counts["Tiling/TilingEngine+StashRestore.swift"] != nil)
        for (file, count) in counts.sorted(by: { $0.key < $1.key }) {
            let unlisted =
                "\(file) seeds a stash capture \(count)× — a new "
                + "seeder states what it seeds and why it is no "
                + "corner, and joins this census (#1177)"
            #expect(
                allowed[file] == count,
                Comment(rawValue: unlisted)
            )
        }
        for (file, count) in allowed {
            let vanished =
                "\(file) no longer seeds \(count)× — re-pin or "
                + "drop its entry"
            #expect(
                counts[file] == count,
                Comment(rawValue: vanished)
            )
        }
    }
}
