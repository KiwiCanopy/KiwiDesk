import Foundation
import Testing

/// "Grey, don't hide" (#171) had been written down and never
/// enforced: `Tests/KiwiDeskGuiTests/` contained **zero**
/// assertions about `.disabled` or `GreyOut`, which is why about
/// a dozen newer surfaces drifted. That absence — not the drift
/// — was the root cause (#520), so the sweep ships with a guard.
///
/// **Design the lens before the list.** The #406 audit's sharpest
/// lesson was `SidebarSearchParityTests`, whose blind spot was
/// structural: it matched only `SettingsSection(…)`, so every
/// `DisclosureGroup` was invisible and no test *could* fail. A
/// hand-written "these nine controls are greyed" would repeat
/// that mistake in a new place — it cannot see site ten.
///
/// So this scans for the shapes that *hide* instead:
///
/// 1. Every editor with an enable toggle greys its dependent
///    block (checked by presence of a gate keyed on the toggle).
/// 2. No Settings view removes a control with `if <flag> { … }`
///    where the flag is one of the known visibility predicates —
///    the shape that produced findings A7 and A8.
///
/// Deliberate exceptions are listed with their reason and are
/// fail-shut: a new one is a conscious edit.
@Suite("Grey, don't hide")
struct GreyOutParityTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    /// Files that must contain a `GreyOut` gate, with the
    /// predicate each one's block gate must be keyed on. These
    /// are the editors whose whole body configures something a
    /// switch can turn off — the #520 class.
    private let gatedEditors: [(file: String, gate: String)] = [
        ("FocusBorderEditor.swift", "enabled"),
        ("SpaceBarGroups.swift", "enabled"),
        ("AppBarGroups.swift", "anyBarShown"),
        ("DragVisualsEditor.swift", "visual.enabled"),
        ("StickyIndicatorEditor.swift", "spaceBarOn"),
        ("AppBarLayoutGroup.swift", "bar.enabled"),
        ("ProfilesSection.swift", "editingStoredProfile"),
        ("SpaceOverrideRows+ModeRows.swift", "resolved"),
        ("AppBarGroups+Colors.swift", "gapOnly"),
    ]

    @Test("every gated editor still greys off its own switch")
    func gatedEditorsCarryTheirGate() throws {
        let files = try SourceScan.swiftSources(under: settingsDir)
        for (name, gate) in gatedEditors {
            let file = try #require(
                files.first { $0.lastPathComponent == name },
                "gated editor file is gone: \(name)"
            )
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            #expect(
                source.contains("GreyOut("),
                Comment(
                    rawValue:
                        "\(name) lost its GreyOut — a control "
                        + "with no effect must be greyed, never "
                        + "left live (#171)"
                )
            )
            #expect(
                source.contains(gate),
                Comment(
                    rawValue:
                        "\(name) no longer gates on \"\(gate)\""
                )
            )
        }
    }

    /// The hiding shape, discovered rather than enumerated.
    /// `if <predicate> {` around settings content removes it from
    /// the tree, which loses the cue that the stored value is
    /// preserved (`docs/ui-patterns.md`). Findings A7
    /// (`if bar.enabled`) and A8 (`if !model.editingStoredProfile`)
    /// were both exactly this.
    private let hidingPredicates = [
        "if bar.enabled {",
        "if !model.editingStoredProfile {",
        "if model.editingStoredProfile {",
        "if style.wrappedValue.enabled {",
        "if visual.enabled {",
    ]

    /// Fail-shut exemptions, one line of reason each. The scan
    /// stays broad ON PURPOSE — narrowing the needles to the two
    /// shapes this sweep fixed would turn the lens back into a
    /// list, and site ten would be invisible again. So a NEW
    /// `if <predicate> {` in Settings fails here until someone
    /// states why it removes rather than dims.
    ///
    /// Every entry below was examined when the guard was
    /// written; all three predate #520 and none of them hides a
    /// control that exists in the other mode.
    private let hidingExempt: [String: String] = [
        // ADDS an explanatory banner in stored-profile mode.
        // Additive, so there is nothing being taken away.
        "ShortcutsSection.swift":
            "adds a banner; removes nothing",
        // Not a view at all — a `String?` computed property
        // choosing which status sentence to return.
        "ProfileHeader.swift":
            "String? branch, not a rendered control",
        // An either/or slot: every branch renders a control (or
        // EmptyView in raw-Lua mode, where a profile-copy verb
        // has no referent). Nothing is hidden that exists in the
        // other branch.
        "SettingsFooter.swift":
            "either/or slot; each mode renders its own verb",
    ]

    /// OS-capability gates are the one legitimate reason to
    /// remove rather than dim: a control for a rendering path
    /// this macOS cannot perform is not "off", it does not
    /// exist. Settled in #390.
    private let capabilityGate = "AppBarStyle.glassAvailable"

    @Test("no settings view hides a control it should grey")
    func noHidingPredicatesRemain() throws {
        var scanned = 0
        let files = try SourceScan.swiftSources(
            under: settingsDir
        )
        for file in files {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            scanned += 1
            let name = file.lastPathComponent
            if hidingExempt[name] != nil { continue }
            for shape in hidingPredicates {
                #expect(
                    !source.contains(shape),
                    Comment(
                        rawValue:
                            "\(name) hides a control with "
                            + "`\(shape)` — grey it instead "
                            + "(#171), or add it to hidingExempt "
                            + "with a stated reason"
                    )
                )
            }
        }
        // A scan over nothing passes vacuously.
        #expect(scanned > 40)
        // An exemption for a file that no longer exists is a
        // stale excuse quietly widening the net.
        let names = Set(files.map(\.lastPathComponent))
        for (file, reason) in hidingExempt {
            #expect(
                names.contains(file),
                Comment(
                    rawValue: "stale hiding exemption: \(file)"
                )
            )
            #expect(!reason.isEmpty)
        }
        #expect(!capabilityGate.isEmpty)
    }

    /// Nested `GreyOut`s multiply their 0.5 opacity to 0.25,
    /// which reads as broken rather than disabled. Every editor
    /// that gained a block gate had to conjoin its inner gates
    /// with the same flag; this pins that the conjunctions are
    /// still there, since the symptom is purely visual and no
    /// other test can see it.
    @Test("inner gates stay conjoined with their block gate")
    func innerGatesAvoidDoubleDimming() throws {
        let files = try SourceScan.swiftSources(under: settingsDir)
        let conjunctions: [(file: String, needle: String)] = [
            ("SpaceBarGroups.swift", "active: enabled"),
            (
                "SpaceBarColorsGroup.swift",
                "active: style.wrappedValue.enabled"
            ),
            ("AppBarLayoutGroup.swift", "active: bar.enabled"),
            (
                "DragVisualsEditor.swift",
                "active: visual.enabled &&"
            ),
        ]
        for (name, needle) in conjunctions {
            let file = try #require(
                files.first { $0.lastPathComponent == name }
            )
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            #expect(
                source.contains(needle),
                Comment(
                    rawValue:
                        "\(name): an inner GreyOut lost its "
                        + "\"\(needle)\" conjunction and will "
                        + "double-dim to 0.25 opacity"
                )
            )
        }
    }
}
