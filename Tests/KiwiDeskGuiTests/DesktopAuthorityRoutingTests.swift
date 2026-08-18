import Foundation
import Testing

/// A binding, profile or Desktop-memory path reads the active
/// Desktop from `NativeSpaces.activeDesktopNumber()` — the MAIN
/// display's — never the global `activeSpaceNumber()` (#888).
///
/// **Why this needs a guard rather than a doc comment.** The two
/// functions have the same shape, the same return type and the
/// same answer on every single-display machine — they diverge
/// only under "Displays have separate Spaces" with two screens,
/// which is the state #888 exists for and the state a dev machine
/// usually is not in. A new consult site reaching for the global
/// number therefore compiles, passes the whole suite locally, and
/// silently reinstates the ambiguity the branch removed. Nothing
/// else can see it: `DesktopAuthorityTests` and its siblings pin
/// the paths that exist today, and a state claim in a doc comment
/// ("binding paths do not read this") is falsified by the commit
/// that adds the next one, somewhere else, with nothing red.
///
/// **The lens, not the list.** The scan discovers every
/// occurrence under `Sources/KiwiDeskCore` and pins a per-file
/// count, so a new call in an unlisted file fails on arrival and
/// a vanished call in a listed one fails too — a count only the
/// status quo can meet is the shape of a guard that has quietly
/// stopped guarding.
///
/// Stated limits, both failing OPEN: a call reached through a new
/// helper inside an allowlisted file is invisible, and
/// `SourceScan.stripComments` cuts each line at its first `//`.
///
/// It lives in the GUI test target because `SourceScan` does
/// (`.claude/rules/tests.md`); it scans `Sources/KiwiDeskCore`.
@Suite("Desktop-authority routing (#888)")
struct DesktopAuthorityRoutingTests {
    private var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    /// Every file allowed to name `activeSpaceNumber` directly,
    /// with today's exact count and the reason it is outside the
    /// authority. **This map is the exemption list** — the
    /// `profiles.md` row and the function's own doc comment carry
    /// the obligation and point here for the files.
    private let allowed: [String: Int] = [
        // The declaration, and the one sanctioned caller: the
        // snapshot's public fallback for a main display the
        // topology cannot name (shared mode's synthetic
        // identifier, no SkyLight, no display-UUID symbol),
        // where the global number IS the main display's.
        "OS/NativeSpaces.swift": 1,
        "OS/NativeSpaces+Desktop.swift": 1,
    ]

    @Test("Only the allowlisted files read the global number")
    func globalReadsStayInsideTheAllowlist() throws {
        var counts: [String: Int] = [:]
        let root = coreRoot
        let prefix = root.path + "/"
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let hits = source.occurrences(of: "activeSpaceNumber")
            guard hits > 0 else { continue }
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            counts[key, default: 0] += hits
        }
        for (file, count) in counts.sorted(by: { $0.key < $1.key }) {
            let unlisted =
                "\(file) names activeSpaceNumber \(count) "
                + "time(s); a binding, profile or Desktop-memory "
                + "path takes NativeSpaces.activeDesktopNumber() "
                + "— the main display's — or justify and re-pin "
                + "the count here (#888)"
            #expect(
                allowed[file] == count,
                Comment(rawValue: unlisted)
            )
        }
        // The inverse: a vanished exemption is unfalsifiable and
        // should be dropped — and it is what proves the scanner
        // reached real files, a mistyped root yielding zero hits
        // everywhere rather than passing vacuously.
        for (file, expected) in allowed {
            let vanished =
                "\(file) no longer names activeSpaceNumber "
                + "\(expected) time(s) — drop or re-pin its "
                + "allowlist entry"
            #expect(
                counts[file] == expected,
                Comment(rawValue: vanished)
            )
        }
    }
}
