import Foundation
import Testing

/// A `StatusItemController` built without an injected handle
/// registers a real menu-bar item that no test process ever
/// removes: a full GUI run parked up to 15 blank slots in the
/// live menu bar and held WindowServer at sustained 40%+ CPU
/// (observed 2026-07-29). Same defect class as tests seizing
/// the real global hotkey chords (#565), same fix: an injection
/// seam (`StatusItemHandle`) whose production default stays
/// live while tests pass a per-file fake.
///
/// Three pins:
/// - a construction under `Tests/` must inject — the bare `()`
///   form is banned outright, so a future suite that forgets
///   the fake fails here instead of silently registering a
///   system item;
/// - `Tests/` may not name the status-bar type at all — sealing
///   the other hole, a test passing a *real* item through the
///   seam;
/// - under `Sources/`, the type is named only by the wrapper
///   the seam defaults to.
///
/// The needle is the bare type token, never the qualified
/// `.system` access: a 79-column wrap between type and member
/// hid a qualified call from `VisibleBoundsRoutingTests`'s
/// first draft, and `swift format` keeps such wraps. The one
/// benign spelling embedding the token is the button type that
/// is the seam's own vocabulary (fakes type their `button`
/// with it), so the scans count net occurrences: total minus
/// the button form.
@Suite("Status-item seam")
struct StatusItemSeamGuardTests {
    private let needle = "NSStatusBar"
    private let benign = "NSStatusBarButton"

    private var testsRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Tests")
    }

    private var sourcesRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
    }

    /// Net occurrences of the forbidden token per file under
    /// `root`, keyed by path relative to it. Files at net zero
    /// are omitted (every `benign` hit embeds one `needle` hit,
    /// so the net is never negative).
    private func netCounts(
        under root: URL
    ) throws -> [String: Int] {
        var counts: [String: Int] = [:]
        let prefix = root.path + "/"
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let hits =
                source.occurrences(of: needle)
                - source.occurrences(of: benign)
            guard hits > 0 else { continue }
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            counts[key] = hits
        }
        return counts
    }

    // MARK: - Pin 1: every construction injects

    /// Shares `testsRoot` and the `SourceScan` walker with pin
    /// 2, whose allowlisted self-hit is the liveness canary for
    /// both: a moved or mistyped root finds zero hits anywhere
    /// and reds there instead of passing vacuously here.
    @Test("Test constructions always inject a handle")
    func bareConstructionStaysOutOfTests() throws {
        let regex = try NSRegularExpression(
            pattern: "StatusItemController\\(\\s*\\)"
        )
        let prefix = testsRoot.path + "/"
        for file in try SourceScan.swiftSources(
            under: testsRoot
        ) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let bare = regex.numberOfMatches(
                in: source,
                range: NSRange(source.startIndex..., in: source)
            )
            let path =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            #expect(
                bare == 0,
                """
                \(path) constructs StatusItemController bare, \
                which registers a real menu-bar item the run \
                never removes — inject a per-file fake handle: \
                StatusItemController(item: <fake>).
                """
            )
        }
    }

    // MARK: - Pin 2: tests never name the system bar

    /// Net-count allowlist for `Tests/`, path-keyed with
    /// today's exact count (the family idiom — the lens, not
    /// the list; see `VisibleBoundsRoutingTests`). The single
    /// entry is this guard itself, which must name the token to
    /// scan for it; that self-hit doubles as the liveness
    /// canary — a moved root yields zero hits everywhere and
    /// reds on the inverse check below rather than passing
    /// vacuously.
    private let allowedInTests: [String: Int] = [
        "KiwiDeskGuiTests/StatusItemSeamGuardTests.swift": 1
    ]

    @Test("Tests reach the menu bar only through the seam")
    func testsNeverNameTheSystemStatusBar() throws {
        let counts = try netCounts(under: testsRoot)
        for (path, found) in counts.sorted(
            by: { $0.key < $1.key }
        ) {
            #expect(
                allowedInTests[path] == found,
                """
                \(path) names \(needle) \(found)x — a test may \
                reach the menu bar only through a fake \
                StatusItemHandle injected at construction, \
                never the live system bar.
                """
            )
        }
        for (path, expected) in allowedInTests {
            #expect(
                counts[path] == expected,
                """
                \(path) no longer names \(needle) \(expected)x \
                — re-pin its entry so the guard keeps biting.
                """
            )
        }
    }

    // MARK: - Pin 3: production access stays in the wrapper

    /// The one file under `Sources/` allowed to name the token:
    /// the wrapper that IS the seam's live default. New
    /// status-bar access routes through `StatusItemHandle`, or
    /// justifies itself and re-pins here. The inverse check is
    /// also this scan's liveness canary.
    private let allowedInSources: [String: Int] = [
        // `SystemStatusItem`, the production default.
        "KiwiDesk/StatusItemHandle.swift": 1
    ]

    @Test("System access stays inside the wrapper")
    func sourcesKeepSystemAccessInTheWrapper() throws {
        let counts = try netCounts(under: sourcesRoot)
        for (path, found) in counts.sorted(
            by: { $0.key < $1.key }
        ) {
            #expect(
                allowedInSources[path] == found,
                """
                \(path) names \(needle) \(found)x — route \
                status-bar access through StatusItemHandle \
                (SystemStatusItem is the one live wrapper), or \
                justify and re-pin the count here.
                """
            )
        }
        for (path, expected) in allowedInSources {
            #expect(
                counts[path] == expected,
                """
                \(path) no longer names \(needle) \(expected)x \
                — drop or re-pin its allowlist entry.
                """
            )
        }
    }
}
