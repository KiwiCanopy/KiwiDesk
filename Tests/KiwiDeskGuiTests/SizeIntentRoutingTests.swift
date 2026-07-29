import Foundation
import Testing

/// `SizeIntent.resize` (#593) tells the animator that a shrinking
/// window may slide its shared edge instead of snapping to target
/// on frame 1. That snap is #45's make-room invariant: mark a path
/// that opens, closes or re-slots windows and the newcomer — which
/// `animate(isNewWindow:)` pre-sets to full size — visibly overlaps
/// the sibling still vacating its room.
///
/// Nothing about a mismarked call site *looks* wrong. It is one
/// extra argument on a `retile` that already existed, it compiles,
/// every unit test passes, and the damage only appears on a real
/// screen during a window-open storm. So the allowlist below is
/// the control: a new file that so much as names the flag fails
/// here until someone writes down why it may.
///
/// **The lens, not the list.** The scan discovers *every*
/// occurrence under `Sources` — both targets, since `KiwiCore`'s
/// `retile` is public and the GUI can reach it — and pins a
/// per-file count, so an unlisted file fails on arrival and a
/// listed file that lost its occurrences fails too (a count only
/// the status quo can meet is the shape of a guard that has
/// quietly stopped guarding). The inverse check is also what
/// proves the scanner reached real files: a mistyped root yields
/// zero hits everywhere and reds here rather than passing
/// vacuously.
///
/// Two numbers per file, because they answer different questions.
/// `names` counts the flag in any spelling — the type, the
/// argument label, the stored property, a local — so a call site
/// cannot hide behind a differently-shaped mention or a hard wrap
/// between the label and its value. `resize` counts the marking
/// itself, and it is scoped to files that already name the flag:
/// unscoped it would drag in every unrelated `.resize` in the
/// tree — the `mouse_resize` coding key, the SkyLight event case,
/// the `KiwiDesk.resize(…)` Lua strings in the keybinding catalog
/// — and an allowlist that is mostly noise stops being read.
///
/// Known limits, both failing **OPEN**, so neither is benign: a
/// marking reached through a helper that itself returns `.resize`
/// from an allowlisted file is invisible (which is exactly the
/// shape `KiwiCore+LayoutCommands.swift` already has — its helper
/// is the reason that file's `resize` count is 1 while its retile
/// reads `Self.sizeIntent(for:)`), and `SourceScan.stripComments`
/// cuts each line at its first `//`, so a string literal carrying
/// `//` before a marking on the same line would erase it.
///
/// It lives in the GUI test target purely because `SourceScan`
/// does — copying the enumerator into `KiwiDeskCoreTests` is the
/// exact drift `.claude/rules/tests.md` ratified that helper to
/// avoid.
@Suite("Size-intent routing")
struct SizeIntentRoutingTests {
    /// One file's relationship to the flag.
    private struct Site: Equatable {
        /// Occurrences of the flag in any spelling.
        let names: Int
        /// Occurrences of `.resize` — the markings themselves.
        let resize: Int
    }

    private var sourcesRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
    }

    /// Every file that may name the flag, by path under
    /// `Sources`, with today's exact counts and its reason.
    /// Anything absent must be at zero.
    ///
    /// **This map is the exemption list.** `SizeIntent`'s own doc
    /// comment argues the principle and points here for the
    /// files rather than keeping a second copy — three prose
    /// copies of the bounds-routing list drifted apart on their
    /// first outing.
    private let allowed: [String: Site] = [
        // The seam, end to end. None of these choose an intent —
        // they thread the caller's, and default it to `.reflow`.
        "KiwiDeskCore/Animation/SizeStep.swift":
            Site(names: 2, resize: 0),
        "KiwiDeskCore/Animation/Spring.swift":
            Site(names: 10, resize: 0),
        "KiwiDeskCore/Animation/AnimationEngine.swift":
            Site(names: 8, resize: 0),
        "KiwiDeskCore/Animation/AnimationEngine+Tick.swift":
            Site(names: 1, resize: 0),
        "KiwiDeskCore/Tiling/TilingEngine.swift":
            Site(names: 8, resize: 0),
        "KiwiDeskCore/App/KiwiCore+Retile.swift":
            Site(names: 4, resize: 0),

        // The marking sites. Each one re-divides room among
        // windows that are already placed, and none of them can
        // introduce an instantly-sized window into its batch.

        // The `resize` verb: every layout path under it writes a
        // ratio or a per-window weight, nothing else.
        "KiwiDeskCore/Commands/KiwiCore+Resize.swift":
            Site(names: 1, resize: 1),
        // A float resizes ITSELF — no tiled window moves at all.
        "KiwiDeskCore/Commands/KiwiCore+ResizeFloating.swift":
            Site(names: 1, resize: 1),
        // Gap edits and the min-size floor: pure geometry over
        // the same windows in the same slots.
        "KiwiDeskCore/Commands/KiwiCore+GapCommands.swift":
            Site(names: 2, resize: 2),
        // The mouse-resize settle and its snap_back fallback.
        "KiwiDeskCore/Tiling/KiwiCore+MouseResizeEnd.swift":
            Site(names: 2, resize: 2),
        // The layout sub-API shares ONE trailing retile across
        // ratio setters and slot-reassigning commands alike, so
        // the choice is made per command name; `resize: 1` is
        // that one lookup, not a marked call.
        "KiwiDeskCore/Commands/KiwiCore+LayoutCommands.swift":
            Site(names: 4, resize: 1),
    ]

    @Test("Only allowlisted files reach the size intent")
    func markingsStayInsideTheAllowlist() throws {
        var found: [String: Site] = [:]
        let root = sourcesRoot
        let prefix = root.path + "/"
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let names = Self.matches(
                "sizeintent",
                in: source,
                caseInsensitive: true
            )
            guard names > 0 else { continue }
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            found[key] = Site(
                names: names,
                resize: Self.matches(
                    "\\.resize\\b",
                    in: source,
                    caseInsensitive: false
                )
            )
        }
        for (file, site) in found.sorted(by: { $0.key < $1.key }) {
            let unlisted =
                "\(file) names the size intent \(site.names) "
                + "time(s) and marks \(site.resize) — justify it "
                + "against #45 and re-pin the counts here"
            #expect(allowed[file] == site, Comment(rawValue: unlisted))
        }
        // The inverse: an allowlisted site that vanished leaves an
        // entry nothing can falsify, and should be dropped.
        for (file, expected) in allowed {
            let vanished =
                "\(file) no longer matches its allowlist entry "
                + "(\(expected.names) named, \(expected.resize) "
                + "marked) — drop or re-pin it"
            #expect(found[file] == expected, Comment(rawValue: vanished))
        }
    }

    /// Non-overlapping regex matches. Private to this suite: the
    /// convention is per-file helpers, and `SourceScan` earns a
    /// member only once a second guard needs the same walk.
    private static func matches(
        _ pattern: String,
        in source: String,
        caseInsensitive: Bool
    ) -> Int {
        guard
            let regex = try? NSRegularExpression(
                pattern: pattern,
                options: caseInsensitive ? [.caseInsensitive] : []
            )
        else { return 0 }
        return regex.numberOfMatches(
            in: source,
            range: NSRange(source.startIndex..., in: source)
        )
    }
}
