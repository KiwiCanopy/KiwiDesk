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
/// literal ban was the wrong rule: Core draws some of its own UI,
/// and that copy crosses no seam. The `allowed` map says which
/// and why.
///
/// **Know what this does NOT cover.** The invariant forbids a
/// finished sentence crossing Core → GUI, and the worst form of
/// that never used `L()` at all: four `ConfigIssue` messages —
/// and, found by the review of the very commit that added this
/// guard, three `StandardLayout` preset summaries — were
/// hardcoded English, invisible to `scripts/extract-keys`, so no
/// locale could translate them however complete it was. A `L()`
/// scan cannot see that class by construction.
///
/// What covers it is per family, not global: Core carries
/// structure instead of copy, and a renderer test proves the
/// family still resolves through a catalog
/// (`ConfigIssueTextTests`, `PresetSummaryCoverageTests`). So a
/// NEW family of Core-authored user-facing text needs its own
/// renderer test — this suite will not notice it.
///
/// Limits, all failing **OPEN**: a sentence built in Core
/// without `L()` is invisible here (see above — structure is the
/// defence); `SourceScan.stripComments` cuts each line at its
/// first `//`, so a `//` inside a string literal preceding a
/// call on the same line would erase it (`ServiceManager.swift`
/// carries two, in a file with no `L(`); and
/// `LocalizationManager.shared.string(_:_:)` is public, so a
/// Core file calling it directly scores zero here AND is missed
/// by `scripts/extract-keys`, whose regex keys on the same `L(`
/// shape — a call that looks localized, never enters a catalog,
/// and never translates. Nothing does that today.
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
        // `L` itself: the plain declaration and the
        // interpolating overload. Both public.
        "Localization/LocalizationManager.swift": 2,
        // Copy for UI that Core itself draws. It reaches a
        // Core-side overlay and never a `Sources/KiwiDesk`
        // consumer, so there is no Core → GUI seam to cross.
        //
        // The sticky mark: `+StickyMarks` is NOT a view — it is
        // a `KiwiCore` extension authoring pill sentences that
        // it hands to `StickyMarkManager.flash`. It is exempt
        // because the renderer is also in Core, so if the
        // overlays ever move to `Sources/KiwiDesk` these four
        // become real violations, with no compiler event to say
        // so. Re-check this entry if that move happens.
        "App/KiwiCore+StickyMarks.swift": 4,
        // The refusal pills (#933, #1055, #1091, widened #1255)
        // are the same shape: a `KiwiCore` extension authoring
        // the own-minimum, neighbor-minimum, own-maximum and
        // no-room-to-grow sentences it hands to the Core-drawn
        // `SizeLimitOverlay`. #1255 added three more — the two
        // no-axis-here readings and the layout-has-no-resizing
        // one — which is what gave the two sound-only refusals
        // something to draw. Same caveat as `+StickyMarks` if
        // the overlays ever move out of Core.
        "App/KiwiCore+SizeLimitPill.swift": 9,
        "Borders/StickyMarkOverlay.swift": 1,
        // The Space Bar's item labels and a11y strings, and the
        // App Bar's a11y labels (#901), drawn by Core.
        "Bar/AppBarItemView.swift": 3,
        "Bar/SpaceBarItemView.swift": 3,
        "Bar/SpaceBarOverlay+FrontApp.swift": 2,
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
