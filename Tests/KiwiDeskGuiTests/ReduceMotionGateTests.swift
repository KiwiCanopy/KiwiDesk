import Foundation
import Testing

/// **Every `withAnimation` in the app's own chrome is gated on
/// Reduce Motion** (#989). A user who asked the system for less
/// motion gets it everywhere or nowhere: a single ungated call
/// animates an insertion, a reorder or a scroll in a window
/// whose every other animation correctly stood down, and
/// nothing about that is visible to a reader who does not have
/// the setting on — which is how five of them shipped at once.
///
/// **Scope, stated because the headline reads wider than the
/// scan**: this holds `withAnimation` and nothing else. The
/// `.animation(_:value:)` modifier is the app's other way to
/// start motion, and it is NOT watched here — extending the
/// same needle to it surfaced 49 sites, ~40 of them the layout
/// schematics' shared `LayoutSchematic.damping`, which is a
/// sweep and a set of per-site rulings rather than a guard
/// clause. Two of that family were gated by hand in #989
/// (`ProfilesSection`'s reorder, which the issue names, and
/// `InactiveDimmed`'s window fade); the rest are unmeasured.
/// Do not read a green here as "every animation is gated".
///
/// The house split (`SettingsModel+Mode`) is what "gated" means
/// here: drop the MOTION, keep the affordance. So the shape
/// required is ONE canonical form — a call whose animation
/// argument can resolve to nil:
///
///     withAnimation(reduceMotion ? nil : .default) { … }
///     withAnimation(reorderAnimation) { … }   // the property decides
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
@Suite("Reduce Motion gating (#989)")
struct ReduceMotionGateTests {
    /// Files whose `withAnimation` may name no gate, each with
    /// the reason it is exempt. Empty by design — an entry here
    /// is a ruling that some motion must run even for a user
    /// who asked for less, which no site has needed yet.
    private static let allowed: [String: String] = [:]

    /// Both spellings, because Swift lets the animation be
    /// omitted: `withAnimation {` is an ungated call that a
    /// paren-only needle cannot see at all. One shipped in
    /// `ShortcutsSection` and left that whole file unscanned
    /// until a guard-prover round found it (#989).
    private static func callSites(
        in source: [Character]
    ) -> [Int] {
        let needle = Array("withAnimation")
        var found: [Int] = []
        for start in source.indices
        where start + needle.count <= source.count
            && Array(source[start..<(start + needle.count)])
                == needle
        {
            // Skip a longer identifier that merely starts with
            // the same letters, and the declaration itself.
            let after = start + needle.count
            guard after < source.count else { continue }
            let next = source[after]
            guard next == "(" || next == " " || next == "{"
            else { continue }
            found.append(start)
        }
        return found
    }

    @Test("Every withAnimation names its Reduce Motion gate")
    func everyAnimationIsGated() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var ungated: [String] = []
        var scanned = 0
        for file in try SourceScan.swiftSources(under: root) {
            let name = file.lastPathComponent
            let source = try SourceScan.strippedSource(at: file)
            guard source.contains("withAnimation") else {
                continue
            }
            let text = Array(source)
            for start in Self.callSites(in: text) {
                scanned += 1
                guard Self.allowed[name] == nil else { continue }
                var cursor = start + "withAnimation".count
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
                if !Self.gates(args, in: source) {
                    ungated.append(name)
                }
            }
        }
        // Fail loudly on an empty scan rather than passing for
        // having found nothing (rule-authoring.md). A FLOOR,
        // not the live count: the number of animations in the
        // app is a value every deliberate addition moves, and
        // pinning it would bill a guard-prover round per
        // animation while catching no regression (tests.md ▸
        // a drawn VALUE).
        #expect(scanned >= 5)
        #expect(ungated.isEmpty, "ungated: \(ungated)")
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
