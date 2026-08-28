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
/// while the `.animation(_:value:)` modifier ran ungated at 44
/// sites — the layout schematics' shared
/// `LayoutSchematic.damping` and six sites elsewhere — and a
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
                for site in SourceScan.callSites(
                    in: text,
                    for: entry,
                    closureCounts: entry == "withAnimation"
                ) {
                    scanned[entry, default: 0] += 1
                    guard Self.allowed[name] == nil else {
                        continue
                    }
                    // A trailing-closure call has no argument at
                    // all, so it can never resolve to nil.
                    guard var cursor = site.paren else {
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
                    let animation = SourceScan.firstArgument(of: args)
                    if !Self.gates(animation, in: source) {
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

    /// Whether an argument can resolve to no animation: it
    /// names `reduceMotion` itself, or names a property whose
    /// declaration in the same file does.
    ///
    /// Deliberately NOT a `contains("Animation")` test. That
    /// shortcut accepted a hard-coded `Animation.interactiveSpring()`
    /// — an animation that plays at full motion for a Reduce
    /// Motion user — because the substring appears in the type
    /// name (guard-prover, #989).
    ///
    /// **Residue, stated because it fails OPEN**: acceptance is
    /// the PRESENCE of the word, never proof that the argument
    /// can reach nil, so `reduceMotion ? .default : .default`
    /// passes (guard-prover, #1069). Deciding that needs types,
    /// which a source scan does not have. What follows from it
    /// is a rule about where the gate may LIVE rather than a
    /// stronger needle: keep the ternary at the call or in a
    /// same-file binding, because every level of indirection
    /// between the word and the nil is a level this cannot
    /// see — `LayoutSchematic.damping` carries the case that
    /// made it concrete.
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
