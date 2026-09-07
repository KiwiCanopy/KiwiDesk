import Foundation
import Testing

/// **Every window states its own accent at its root** (#1293).
///
/// `Color.accentColor` is retired because it reads the USER'S
/// system accent, and an unstyled control takes whatever tint it
/// finds — so a window root that states none renders the user's
/// accent inside a kiwi app. That shipped in the ⌃⌥K panel: a
/// pink chip and a pink button on a Mac whose accent is pink.
///
/// The fix was a third hand-copy of one line, which is where
/// [parity-tests.md](../../.claude/rules/parity-tests.md) puts
/// the census — past two mirrors, ship a forget-proof test. Two
/// windows carried it and nothing read either, so deleting a
/// `.tint` redded nothing and the next window would repeat #1293
/// by omission exactly as this one did (code review).
///
/// **This counts the STATEMENT, not its effect.** A window
/// listed here whose controls all state their own style needs
/// the line anyway — it is the floor for the next control added
/// without one, which is the failure mode, so an inert-looking
/// tint is the point rather than a redundancy to prune.
///
/// **Two residues, both fail-OPEN, both stated rather than
/// closed** (guard-prover):
///
/// It reads the file, not the view tree, so a tint moved OFF the
/// root chain onto some inner container passes here while every
/// control outside that container falls through to the system
/// accent — measured green. Locating the root chain in source
/// would mean pinning a modifier order that is free to change,
/// which is the value pin tests.md refuses; the eye and review
/// hold that half.
///
/// And the census is hand-listed, so a FOURTH window this app
/// opens is covered only once someone adds it. The floor below
/// proves the three named files still exist; nothing proves the
/// list is complete, because a SwiftUI root is a file rather
/// than a registry there is anything to reflect over.
@Suite("Window roots state the accent (#1293)")
struct WindowRootTintTests {
    /// The root view of each window this app opens, and the tint
    /// each must state. Hand-listed because there is nothing to
    /// reflect over — a SwiftUI root is a file, not a registry —
    /// so the clause below floors it against the tree instead.
    private static let roots = [
        "SettingsView.swift",
        "OnboardingView.swift",
        "ShortcutsPanelView.swift",
    ]

    /// What a root must spell. The TOKEN family, never which
    /// token: a window choosing a different `SettingsTheme`
    /// member is a design change, and a window spelling
    /// `Color.accentColor` is the defect (tests.md ▸ #1021).
    private static let statement = ".tint(SettingsTheme."

    /// The retired spelling, held at zero in the same walk so a
    /// root cannot satisfy the clause above by stating the
    /// system accent.
    private static let retired = "Color.accentColor"

    private static var guiRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
    }

    @Test("Every window root states its tint")
    func everyRootStatesTheTint() throws {
        var seen: [String: String] = [:]
        for file in try SourceScan.swiftSources(under: Self.guiRoot)
        where Self.roots.contains(file.lastPathComponent) {
            seen[file.lastPathComponent] =
                try SourceScan.strippedSource(at: file)
        }
        // The census is hand-listed, so FLOOR it against the file
        // system: a root renamed out from under this list would
        // otherwise leave the clause green over fewer windows
        // than it names (memory: a derived register still needs
        // tree coverage).
        #expect(
            Set(seen.keys) == Set(Self.roots),
            """
            a censused window root is missing from the tree — \
            renamed? \(Set(Self.roots).subtracting(seen.keys))
            """
        )
        for (name, source) in seen {
            #expect(
                source.contains(Self.statement),
                """
                \(name) states no root tint — an unstyled control \
                below it renders the USER'S system accent (#1293)
                """
            )
            #expect(
                !source.contains(Self.retired),
                "\(name) spells the retired \(Self.retired)"
            )
        }
    }
}
