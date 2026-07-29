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
///   form (and its `.init` spelling) is banned outright, so a
///   future suite that forgets the fake fails here instead of
///   silently registering a system item;
/// - `Tests/` may not name the status-bar type at all — a
///   hand-rolled live handle cannot be built without it. The
///   third route, passing the production wrapper through the
///   seam, is sealed by construction instead of scanned:
///   `SystemStatusItem` is file-scoped `private` beside the
///   controller, unnameable from tests even under
///   `@testable import`;
/// - under `Sources/`, the token is named only by the file
///   holding that wrapper.
///
/// The needle is the bare type token, never the qualified
/// `.system` access: a 79-column wrap between type and member
/// hid a qualified call from `VisibleBoundsRoutingTests`'s
/// first draft, and `swift format` keeps such wraps. The one
/// benign spelling embedding the token is the button type that
/// is the seam's own vocabulary (fakes type their `button`
/// with it), so the scans count net occurrences: total minus
/// the button form.
///
/// Two disclosed limits. `SourceScan.stripComments` cuts each
/// line at its first `//` even inside a string literal, so a
/// `//`-bearing literal ahead of a needle on the same line
/// erases that hit — fail-open; weigh it when adding a needle.
/// And production wiring is out of reach: a future test that
/// instantiates `AppDelegate` re-leaks live items through a
/// path no pin scans — the fix at that point is seaming
/// `AppDelegate` itself, not widening these scans.
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

    /// The injected-form floor at the end is this pin's own
    /// liveness canary: a controller rename (or a moved root)
    /// finds zero injected constructions and reds there,
    /// instead of the ban scanning forever for a type name
    /// that no longer exists. Pin 2's allowlisted self-hit
    /// still covers root-and-walker liveness for the token
    /// scans.
    @Test("Test constructions always inject a handle")
    func bareConstructionStaysOutOfTests() throws {
        // `.init` sugar included: the spelled-out initializer
        // reference names no banned token, so nothing else
        // would catch it.
        let bareForm = try NSRegularExpression(
            pattern:
                "StatusItemController(?:\\s*\\.\\s*init)?"
                + "\\(\\s*\\)"
        )
        let injectedForm = try NSRegularExpression(
            pattern: "StatusItemController\\(\\s*item:"
        )
        var injected = 0
        let prefix = testsRoot.path + "/"
        for file in try SourceScan.swiftSources(
            under: testsRoot
        ) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let range = NSRange(
                source.startIndex...,
                in: source
            )
            let bare = bareForm.numberOfMatches(
                in: source,
                range: range
            )
            injected += injectedForm.numberOfMatches(
                in: source,
                range: range
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
        #expect(
            injected > 0,
            """
            No injected StatusItemController(item:) \
            construction found under Tests/ — a rename has \
            vacated this pin's needles; update them so the \
            bare-construction ban keeps biting.
            """
        )
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
                never the live system bar; or justify and \
                re-pin the count here.
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
    /// the controller file holding `SystemStatusItem`, the
    /// file-scoped-private wrapper that IS the seam's live
    /// default. New status-bar access routes through
    /// `StatusItemHandle`, or justifies itself and re-pins
    /// here. The inverse check is also this scan's liveness
    /// canary.
    private let allowedInSources: [String: Int] = [
        // `SystemStatusItem`, sealed beside the controller.
        "KiwiDesk/StatusItemController.swift": 1
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
