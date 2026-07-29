import Foundation
import Testing

/// `BatchSizing.allSpringSized` (#593) promises the animator that
/// every window in a pass is spring-sized, which lets a shrinking
/// one slide its shared edge instead of snapping to target on
/// frame 1. That snap is #45's make-room invariant: promise it of
/// a pass that opens, closes or re-slots a window and the
/// newcomer — which `animate(isNewWindow:)` paints at full size
/// immediately — visibly overlaps the sibling still vacating its
/// room. `BatchSizing`'s own doc comment argues why; this suite is
/// the net, and deliberately keeps no second copy of the argument.
///
/// Nothing about a false promise *looks* wrong. It is one extra
/// argument on a `retile` that already existed, it compiles, every
/// unit test passes, and the damage only appears on a real screen
/// during a window-open storm. So the allowlist below is the
/// control: a new file that so much as names the type fails here
/// until someone writes down why it may.
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
/// Two numbers per file, and **keep both** — they fail on
/// different edits. `names` counts the type in any spelling, so a
/// call site cannot hide behind a hard wrap between an argument
/// label and its value. `promises` counts the promise itself, and
/// the case it alone catches is the single most destructive edit
/// available here: flipping a default from `.mayInstantSize` to
/// `.allSpringSized` at `KiwiCore+Retile.swift` or
/// `TilingEngine.swift` promises on behalf of every unmarked call
/// site in the codebase and moves only the second count. A future
/// author trimming a "redundant" number would drop exactly the one
/// that matters.
///
/// Known limits, all failing **OPEN**, so none is benign:
///
/// - A promise reached through a helper that itself returns
///   `.allSpringSized` from an allowlisted file is invisible.
///   `KiwiCore+LayoutCommands.swift` has that shape by design —
///   `promiseAllWindowsSpringSized()` is counted, but a *new*
///   caller of it inside an already-listed file would not move a
///   count. `BatchSizingCommandTests` is the behavioural net for
///   that, and it is the only guard here that catches a
///   **forgotten** raise rather than an unexpected one.
/// - `promises` is file-wide and unanchored, so an allowlisted
///   file could lose a real promise and gain an unrelated mention
///   in one edit and stay green. Contrived as a single change, but
///   `KiwiCore+Resize.swift` and `KiwiCore+MouseResizeEnd.swift`
///   are where an unrelated mention is plausible. Anchoring to
///   `sizing:\s*\.allSpringSized` would close it at the cost of
///   missing hard-wrapped sites — which is what `names` exists
///   for, so the pair stays loose rather than precise.
/// - `SourceScan.stripComments` cuts each line at its first `//`,
///   so a string literal carrying `//` before a promise on the
///   same line would erase it. Stripping does mean doc-comment
///   churn cannot move the pins, which is why it is worth the
///   exposure.
///
/// It lives in the GUI test target purely because `SourceScan`
/// does — copying the enumerator into `KiwiDeskCoreTests` is the
/// exact drift `.claude/rules/tests.md` ratified that helper to
/// avoid.
@Suite("Batch-sizing routing")
struct BatchSizingRoutingTests {
    /// One file's relationship to the type.
    private struct Site: Equatable {
        /// Occurrences of the type in any spelling.
        let names: Int
        /// Occurrences of the promise itself.
        let promises: Int
    }

    private var sourcesRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
    }

    /// Every file that may name the type, by path under
    /// `Sources`, with today's exact counts and its reason.
    /// Anything absent must be at zero.
    ///
    /// **This map is the exemption list**, and the only copy of
    /// it: `BatchSizing`'s doc comment and the two rule files
    /// point here rather than keeping one.
    private let allowed: [String: Site] = [
        // The type itself.
        "KiwiDeskCore/Animation/BatchSizing.swift":
            Site(names: 2, promises: 0),

        // The seam, end to end. None of these promise anything —
        // they thread the caller's and default it to the
        // pessimistic case. `AnimationEngine` names the promise
        // once, in the re-seat guard that keeps a mid-flight
        // switch into it from rebounding the window.
        "KiwiDeskCore/Animation/FrameAnimation.swift":
            Site(names: 10, promises: 0),
        "KiwiDeskCore/Animation/AnimationEngine.swift":
            Site(names: 11, promises: 1),
        "KiwiDeskCore/Animation/AnimationEngine+Tick.swift":
            Site(names: 2, promises: 0),
        "KiwiDeskCore/Animation/SizeStep.swift":
            Site(names: 3, promises: 0),
        "KiwiDeskCore/Tiling/TilingEngine.swift":
            Site(names: 9, promises: 0),
        "KiwiDeskCore/App/KiwiCore+Retile.swift":
            Site(names: 4, promises: 0),
        // The per-dispatch flag the layout setters raise.
        "KiwiDeskCore/App/KiwiCore.swift":
            Site(names: 1, promises: 0),

        // The promising sites. Each re-divides room among windows
        // already placed, and none can introduce an
        // instantly-sized window into its batch.

        // The `resize` verb: every layout path under it writes a
        // ratio or a per-window weight, nothing else.
        "KiwiDeskCore/Commands/KiwiCore+Resize.swift":
            Site(names: 2, promises: 1),
        // A float resizes ITSELF — no tiled window moves at all.
        "KiwiDeskCore/Commands/KiwiCore+ResizeFloating.swift":
            Site(names: 2, promises: 1),
        // Gap edits and the min-size floor: pure geometry over
        // the same windows in the same slots.
        "KiwiDeskCore/Commands/KiwiCore+GapCommands.swift":
            Site(names: 4, promises: 2),
        // NOT LISTED, deliberately, and worth knowing why:
        // `Tiling/KiwiCore+MouseResizeEnd.swift`. A mouse settle
        // looks like the keyboard `resize` verb — it writes a
        // ratio and retiles — but the dragged window arrives
        // already at its final frame, placed by the pointer, and
        // the un-forced retile skips it inside the ±2 pt
        // tolerance. An instantly-sized window in the batch is
        // precisely what the promise denies, so that path stays at
        // zero rather than earning an entry here.

        // The layout sub-API shares ONE trailing retile across
        // ratio setters and slot-reassigning commands alike, so
        // the promise is raised per write instead. This file holds
        // the helper and consumes the flag; the raises are counted
        // in the three files below.
        "KiwiDeskCore/Commands/KiwiCore+LayoutCommands.swift":
            Site(names: 3, promises: 2),
        // Ratio / slot-size writes, each counted twice: the global
        // setter and its `_override` twin. That cross product is
        // the whole reason these live beside the write rather than
        // in a list of command names — one round shipped with
        // `bsp.set_ratio_h` raised and `_override` not.
        "KiwiDeskCore/Commands/KiwiCore+BspCommands.swift":
            Site(names: 4, promises: 4),
        "KiwiDeskCore/Commands/KiwiCore+StackCommands.swift":
            Site(names: 2, promises: 2),
        "KiwiDeskCore/Commands/KiwiCore+ScrollCommands.swift":
            Site(names: 2, promises: 2),
    ]

    /// Any spelling of the type — the argument label, the stored
    /// property, the enum, a local, and the promise helper whose
    /// name contains none of the others.
    private static let namePattern =
        "batchsizing|\\bsizing\\b|springsized"
    /// The promise itself: the case, or a call to the helper that
    /// raises it.
    private static let promisePattern =
        "\\.allSpringSized\\b|promiseAllWindowsSpringSized\\(\\)"

    @Test("Only allowlisted files reach the batch sizing")
    func promisesStayInsideTheAllowlist() throws {
        var found: [String: Site] = [:]
        let root = sourcesRoot
        let prefix = root.path + "/"
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let names = Self.matches(
                Self.namePattern,
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
                promises: Self.matches(
                    Self.promisePattern,
                    in: source,
                    caseInsensitive: false
                )
            )
        }
        for (file, site) in found.sorted(by: { $0.key < $1.key }) {
            let unlisted =
                "\(file) names the batch sizing \(site.names) "
                + "time(s) and promises \(site.promises) — justify "
                + "it against #45 and re-pin the counts here"
            #expect(
                allowed[file] == site,
                Comment(rawValue: unlisted)
            )
        }
        // The inverse: an allowlisted site that vanished leaves an
        // entry nothing can falsify, and should be dropped.
        for (file, expected) in allowed {
            let vanished =
                "\(file) no longer matches its allowlist entry "
                + "(\(expected.names) named, \(expected.promises) "
                + "promised) — drop or re-pin it"
            #expect(
                found[file] == expected,
                Comment(rawValue: vanished)
            )
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
