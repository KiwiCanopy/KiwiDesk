import Foundation
import Testing

/// `KiwiDeskCore` must not render a user-facing sentence and hand
/// it to the GUI (#96): it reports **structure** — a case, an
/// enum, a value type — and the GUI says it in the user's
/// language (`Conflict` → `ConflictText`, `ConfigIssue.Kind` →
/// `ConfigIssueText`).
///
/// `core-boundaries.md` asserted this as "Core holds no `L()`
/// call site outside `Localization/`" with nothing enforcing it,
/// and by #601 five files falsified it — a rule that loads on
/// every Core edit, teaching a guarantee the tree did not keep.
/// This is that guard.
///
/// **It pins the file list, not the phrasing**, because the
/// literal ban was the wrong rule. Core's in-app overlays are
/// AppKit views that draw their own text and are already
/// `@MainActor`; they sit under `Sources/KiwiDeskCore` only
/// because the subsystem map puts the overlays there. There is
/// no seam for them to cross, so `L()` is right in them and they
/// are allowlisted. What the invariant actually forbids is a
/// *finished sentence* crossing Core → GUI, and the worst form
/// of that never used `L()` at all: four `ConfigIssue` messages
/// were hardcoded English, invisible to `scripts/extract-keys`,
/// so no locale could translate them however complete it was.
/// That class is unreachable by any string scan — the type-level
/// fix is what prevents it, and `ConfigIssueTextTests` is what
/// keeps every case renderable.
///
/// Limits, both failing **OPEN**: a sentence built in Core
/// without `L()` is invisible here (see above — structure is the
/// defence), and `SourceScan.stripComments` cuts each line at
/// its first `//`, so a `//` inside a string literal preceding a
/// call on the same line would erase it.
///
/// Lives in the GUI test target only because `SourceScan` does;
/// it scans `Sources/KiwiDeskCore`.
@Suite("Core localization boundary")
struct CoreLocalizationBoundaryTests {
    private var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    /// Every file in Core allowed to call `L()`, by path, with
    /// today's exact count and why it is not a seam crossing.
    /// Anything absent must be at zero.
    ///
    /// **This map is the exemption list** — `core-boundaries.md`
    /// carries the principle and points here for the files,
    /// rather than restating them.
    private let allowed: [String: Int] = [
        // The routing function's own declaration and its
        // internal overload.
        "Localization/LocalizationManager.swift": 2,
        // In-app overlay views. Each renders its own on-screen
        // text on the main actor and hands nothing to the GUI
        // layer, so there is no Core → GUI seam to cross.
        // The sticky mark's pill copy and its a11y label:
        "App/KiwiCore+StickyMarks.swift": 4,
        "Borders/StickyMarkOverlay.swift": 1,
        // The Space Bar's own item labels and a11y strings:
        "Bar/SpaceBarItemView.swift": 3,
        "Bar/SpaceBarOverlay+FrontApp.swift": 1,
    ]

    /// `L(` preceded by an identifier character is a different
    /// symbol, not the routing function — `URL(` is the one that
    /// bites, and a plain substring count would score it.
    private func localizationCalls(in source: String) -> Int {
        var total = 0
        var previous: Character?
        var iterator = source.startIndex
        while iterator < source.endIndex {
            let character = source[iterator]
            let next = source.index(after: iterator)
            if character == "L", next < source.endIndex,
                source[next] == "("
            {
                let isSuffix =
                    previous?.isLetter == true
                    || previous?.isNumber == true
                    || previous == "_"
                if !isSuffix { total += 1 }
            }
            previous = character
            iterator = next
        }
        return total
    }

    @Test("Only the allowlisted Core files call L()")
    func localizationCallsStayInsideTheAllowlist() throws {
        var counts: [String: Int] = [:]
        let root = coreRoot
        let prefix = root.path + "/"
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let hits = localizationCalls(in: source)
            guard hits > 0 else { continue }
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            counts[key, default: 0] += hits
        }
        for (file, count) in counts.sorted(by: { $0.key < $1.key }) {
            let unlisted =
                "\(file) calls L() \(count) time(s); return "
                + "structure and render it at the GUI boundary "
                + "(see ConfigIssueText), or justify and re-pin "
                + "the count here"
            #expect(
                allowed[file] == count,
                Comment(rawValue: unlisted)
            )
        }
        // The inverse: a vanished call makes its entry
        // unfalsifiable, and a mistyped root would otherwise pass
        // vacuously with zero hits everywhere.
        for (file, expected) in allowed {
            let vanished =
                "\(file) no longer calls L() \(expected) "
                + "time(s) — drop or re-pin its allowlist entry"
            #expect(
                counts[file] == expected,
                Comment(rawValue: vanished)
            )
        }
    }

    @Test("The needle ignores identifiers ending in L")
    func needleIgnoresSuffixMatches() {
        // Proves the guard cannot fail OPEN on the common case:
        // `URL(` outnumbers `L(` in this tree, and a substring
        // count would have scored every one of them.
        #expect(localizationCalls(in: "URL(string: x)") == 0)
        #expect(localizationCalls(in: "myL(1)") == 0)
        #expect(localizationCalls(in: "L(\"k\", \"E\")") == 1)
        #expect(localizationCalls(in: "return L(a) + L(b)") == 2)
    }
}
