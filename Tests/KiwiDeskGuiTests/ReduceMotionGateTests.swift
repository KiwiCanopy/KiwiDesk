import Foundation
import Testing

/// **Every animation the app's own chrome starts is gated on
/// Reduce Motion** (#989, #1069). A user who asked the system
/// for less motion gets it everywhere or nowhere: a single
/// ungated call animates an insertion, a reorder or a scroll in
/// a window whose every other animation correctly stood down,
/// and nothing about that is visible to a reader who does not
/// have the setting on — which is how five of them shipped at
/// once.
///
/// **Both ways in are scanned**, because half the invariant is
/// no invariant: `withAnimation` was gated and guarded by #989
/// while the `.animation(_:value:)` modifier ran ungated at ~40
/// sites — the layout schematics' shared
/// `LayoutSchematic.damping` and six hover/focus fades — and a
/// green here said "every animation is gated" over them
/// (#1069). `entryPoints` is the census of the spellings that
/// start motion; a new one joins it.
///
/// The house split (`SettingsModel+Mode`) is what "gated" means
/// here: drop the MOTION, keep the affordance. So the shape
/// required is ONE canonical form — a call whose animation
/// argument can resolve to nil:
///
///     withAnimation(reduceMotion ? nil : .default) { … }
///     withAnimation(reorderAnimation) { … }   // the property decides
///     .animation(reduceMotion ? nil : .default, value: x)
///     .animation(damping, value: x)           // ditto
///
/// The `if reduceMotion { … } else { withAnimation … }` spelling
/// is deliberately NOT accepted, and the three sites that used
/// it were normalized to the form above. A guard-prover round
/// is why (#989): recognising that shape needs a proximity
/// window, and any window wide enough to span the `else` is
/// also satisfied by an unrelated mention of the word — a
/// function's own `reduceMotion:` parameter was enough to make
/// every ungated call inside it unprovable.
///
/// A model has no environment to read, so it takes
/// `reduceMotion` as a parameter from its caller
/// (`flipSettingsMode`, `setAutoStart`) and names it at the
/// call, or resolves it into a local the call names.
@Suite("Reduce Motion gating (#989, #1069)")
struct ReduceMotionGateTests {
    /// Files whose animations may name no gate, each with the
    /// reason it is exempt. Empty by design — an entry here is a
    /// ruling that some motion must run even for a user who
    /// asked for less, which no site has needed yet.
    ///
    /// The case that looks like one and is not is an activity
    /// indicator; `.claude/rules/gui.md` ▸ the Reduce Motion
    /// gate rules it, and neither of the two the tour draws
    /// needed an entry (#1069).
    private static let allowed: [String: String] = [:]

    /// The spellings that START motion. Both are scanned and
    /// each must find at least one site, so a needle that stops
    /// matching cannot leave its half silently unwatched.
    private static let entryPoints = [
        "withAnimation", ".animation",
    ]

    /// Every call of `entry`, by index. The acceptance is per
    /// spelling because only the imperative one may omit its
    /// parens: Swift defaults the animation, so `withAnimation {`
    /// is an ungated call a paren-only needle cannot see at all —
    /// one shipped in `ShortcutsSection` and left that whole file
    /// unscanned until a guard-prover round found it (#989). The
    /// modifier has no such shape, and a space or brace after it
    /// is some other construct rather than a call.
    private static func callSites(
        in source: [Character],
        for entry: String
    ) -> [Int] {
        let needle = Array(entry)
        let bare = entry == "withAnimation"
        var found: [Int] = []
        for start in source.indices
        where start + needle.count <= source.count
            && Array(source[start..<(start + needle.count)])
                == needle
        {
            // Skip a longer identifier that merely starts with
            // the same letters (`.animations`, which the
            // settings model spells all over), and the
            // declaration itself.
            let after = start + needle.count
            guard after < source.count else { continue }
            let next = source[after]
            guard next == "(" || (bare && (next == " " || next == "{"))
            else { continue }
            found.append(start)
        }
        return found
    }

    @Test("Every animation names its Reduce Motion gate")
    func everyAnimationIsGated() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var ungated: [String] = []
        var scanned: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let name = file.lastPathComponent
            let source = try SourceScan.strippedSource(at: file)
            let text = Array(source)
            for entry in Self.entryPoints
            where source.contains(entry) {
                for start in Self.callSites(in: text, for: entry) {
                    scanned[entry, default: 0] += 1
                    guard Self.allowed[name] == nil else {
                        continue
                    }
                    var cursor = start + entry.count
                    // A trailing-closure call has no argument at
                    // all, so it can never resolve to nil.
                    guard text[cursor] == "(" else {
                        ungated.append(name)
                        continue
                    }
                    let args =
                        SourceScan.balanced(
                            text,
                            from: &cursor,
                            open: "(",
                            close: ")"
                        ) ?? ""
                    if !Self.gates(Self.animationArgument(args), in: source) {
                        ungated.append("\(name) [\(entry)]")
                    }
                }
            }
        }
        // Fail loudly on an empty scan rather than passing for
        // having found nothing (rule-authoring.md), and PER
        // needle: a `withAnimation` half that still matches
        // hides a modifier half that has stopped. A FLOOR, not
        // the live count — the number of animations in the app
        // is a value every deliberate addition moves, and
        // pinning it would bill a guard-prover round per
        // animation while catching no regression (tests.md ▸
        // a drawn VALUE).
        for entry in Self.entryPoints {
            #expect(
                scanned[entry, default: 0] >= 5,
                "no sites scanned for \(entry)"
            )
        }
        #expect(ungated.isEmpty, "ungated: \(ungated)")
    }

    /// The animation argument alone. `.animation(_:value:)`
    /// carries the value it keys on as a second argument, and
    /// only the first one is the animation — split at the
    /// top-level comma, since an animation may carry commas of
    /// its own (`.spring(response:dampingFraction:)`).
    private static func animationArgument(
        _ args: String
    ) -> String {
        var depth = 0
        for (offset, character) in args.enumerated() {
            switch character {
            case "(", "[": depth += 1
            case ")", "]": depth -= 1
            case "," where depth == 0:
                return String(args.prefix(offset))
            default: break
            }
        }
        return args
    }

    /// Whether an argument can resolve to no animation: it
    /// names `reduceMotion` itself, or names a property whose
    /// declaration in the same file does.
    ///
    /// Deliberately NOT a `contains("Animation")` test. That
    /// shortcut accepted a hard-coded `Animation.interactiveSpring()`
    /// — an animation that plays at full motion for a Reduce
    /// Motion user — because the substring appears in the type
    /// name (guard-prover, #989).
    private static func gates(
        _ args: String,
        in source: String
    ) -> Bool {
        let args = args.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !args.isEmpty else { return false }
        if args.contains("reduceMotion") { return true }
        // A bare identifier: resolve it to its declaration and
        // require the gate there.
        let identifier = args.trimmingCharacters(
            in: CharacterSet(charactersIn: "()")
        )
        guard
            identifier.allSatisfy({
                $0.isLetter || $0.isNumber || $0 == "_"
            }), !identifier.isEmpty
        else { return false }
        // Both declaration forms the tree uses: a computed
        // property (`var x: Animation? { … }`) and a local or
        // stored binding with an initializer (`let fade: … = …`).
        let forms = [
            "((?:var|let)\\s+\(identifier)\\s*:[^={\n]*\\{[^}]*\\})",
            "((?:var|let)\\s+\(identifier)\\s*(?::[^=\n]*)?=[^\n]*)",
        ]
        return forms.contains { pattern in
            SourceScan.firstMatch(in: source, pattern: pattern)?
                .contains("reduceMotion") == true
        }
    }
}
