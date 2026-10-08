import Foundation
import Testing

/// Every raw read of the screen-covering verdict in Core is
/// classified, or it reds (#1788). A reader asking whether a
/// TRACKED window is presenting takes `KiwiCore.presents`, which
/// rules the float gate once; the raw `covers` / `coversAScreen`
/// is for a CANDIDATE frame whose float ruling the caller already
/// made (the fit, the gather) and for the verdict's own home. A
/// new raw caller is the drift #1788 closes, so it reds here
/// until it routes through the door or names its reason.
///
/// Pinned by COUNT per file over comment-stripped source: a
/// routed site swapped for another raw read in the same file
/// stays green, which the consumer suites own.
@Suite("Screen-covering caller census")
struct ScreenCoveringCallerCensusTests {
    /// Files spelling the raw verdict, with their reason.
    private let allowed: [String: Int] = [
        // The home: both definitions, `coversAScreen`'s own
        // `covers`, the shelf's front-window reads, the door and
        // the crossing's before/after.
        "App/KiwiCore+ScreenCovering.swift": 8,
        // The float fit judges the frame it would write, on the
        // workspace its caller names (#1787).
        "App/KiwiCore+FloatClamp.swift": 1,
        // The gather judges the frame a member would show, on the
        // entry the mode write makes (#1787).
        "App/KiwiCore+FloatGather.swift": 1,
    ]

    @Test("every raw screen-covering read in Core is classified")
    func everyCallerIsClassified() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let prefix = root.path + "/"
        var counts: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let key = String(file.path.dropFirst(prefix.count))
            let source = try SourceScan.strippedSource(at: file)
            let hits =
                source.occurrences(of: "coversAScreen(")
                + source.occurrences(of: "covers(")
            guard hits > 0 else { continue }
            counts[key] = hits
        }
        #expect(counts["App/KiwiCore+ScreenCovering.swift"] != nil)
        for (file, count) in counts.sorted(by: { $0.key < $1.key }) {
            let unlisted =
                "\(file) reads the screen-covering verdict "
                + "\(count)× — ask KiwiCore.presents for a tracked "
                + "window, or classify and pin it here (#1788)"
            #expect(
                allowed[file] == count,
                Comment(rawValue: unlisted)
            )
        }
        for (file, pinned) in allowed {
            #expect(
                counts[file] == pinned,
                "\(file) no longer reads the verdict \(pinned)×"
            )
        }
    }
}
