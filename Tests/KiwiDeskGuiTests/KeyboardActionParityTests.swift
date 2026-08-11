import Foundation
import Testing

/// #678 Phase 4 pass 10, turn 20a rule 1: **the drag is the
/// shortcut and the menu is the mechanism** — so every mechanism
/// has to be reachable without the gesture that is merely its
/// shortcut.
///
/// A `.contextMenu` is right-click and nothing else. macOS has no
/// default key that opens a focused control's contextual menu, so
/// a mechanism that lives only there is pointer-only however many
/// keyboard-navigable things sit beside it. Three of the four
/// sites in this tree were exactly that when the pass opened, and
/// one of them — the spaces row — held Move Up, Move Down and
/// Make Fallback, which have no on-screen control anywhere else.
///
/// The pairing is asserted as a COUNT per file rather than as a
/// named list of call sites. A list is one more place to forget
/// and would go green on a fifth menu nobody added to it; equal
/// counts red on the next unpaired `.contextMenu` whoever writes
/// it, which is the whole point of putting the guard here instead
/// of in a review checklist.
///
/// What this does NOT claim, stated so the green is not read as
/// more than it is: an `.accessibilityActions` reaches VoiceOver,
/// not a Tab-only keyboard user. Turn 20a also asked for a
/// visible `⋯` per draggable row; the owner ruled against it on
/// 2026-08-11, standing by the 2026-08-04 clutter rejection
/// recorded in `SpaceAssignmentChip`'s docstring, so that gap is
/// deliberate. This guard holds the half that was ruled in.
@Suite("Keyboard action parity")
struct KeyboardActionParityTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    @Test("every context menu is also a set of named actions")
    func everyContextMenuHasAccessibilityActions() throws {
        let files = try SourceScan.swiftSources(under: settingsDir)
        var checked = 0
        for file in files {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            // No leading dot: `ColorField` calls it on `self`
            // from a `View` extension, and that spelling is a
            // context menu like any other.
            let menus =
                source.components(
                    separatedBy: "contextMenu {"
                ).count - 1
            guard menus > 0 else { continue }
            checked += 1
            let actions =
                source.components(
                    separatedBy: "accessibilityActions {"
                ).count - 1
            #expect(
                menus == actions,
                Comment(
                    rawValue:
                        "\(file.lastPathComponent) has \(menus) "
                        + "context menu(s) and \(actions) "
                        + "accessibility action set(s) — a "
                        + "mechanism that lives only behind a "
                        + "right-click is pointer-only, and macOS "
                        + "has no key that opens one (turn 20a "
                        + "rule 1)"
                )
            )
        }
        // A floor, not an exact count: this suite's job is the
        // pairing, and a new menu is welcome. What the floor
        // catches is the scan reading zero files — a renamed
        // directory or a broken walker passes every #expect above
        // by never reaching one.
        #expect(
            checked >= 4,
            Comment(
                rawValue:
                    "only \(checked) file(s) with a context menu "
                    + "were scanned — the walk found less than "
                    + "the tree is known to hold, so the pairing "
                    + "was not actually checked"
            )
        )
    }

    /// Turn 20a rule 4: **every shape change states a focus
    /// destination** — and the per-space override editor is the
    /// one sub-view in the tree that the shell cannot state one
    /// for, since the shell only sees `SettingsDestination`
    /// pushes and this branch is view state inside Spaces.
    ///
    /// Three wirings, three sites, and every one of them is a
    /// single line that reads as decoration and deletes without
    /// a compiler complaint. A `@FocusState` whose binding is
    /// never attached compiles, runs, and simply never moves
    /// focus — the failure is silent to everything except a
    /// person trying to use the keyboard, which is exactly the
    /// class of defect this pass exists to close.
    ///
    /// Each needle names the USE site rather than the
    /// declaration (the Monitors lesson: a bare property name
    /// matched its own `@FocusState` line and went green with
    /// every attachment deleted).
    @Test("the override sub-view states its focus destinations")
    func overrideEditorStatesItsFocusDestinations() throws {
        let wirings: [Wiring] = [
            Wiring(
                "SpacesSection+Overrides.swift",
                ".focused($overridesBackFocused)",
                "entering the sub-view focuses its back crumb"
            ),
            Wiring(
                "SpacesSection+Overrides.swift",
                "onAppear { overridesBackFocused = true }",
                "and something has to raise the flag"
            ),
            Wiring(
                "SpacesSection+Customize.swift",
                ".focused($returningRow, equals: space)",
                "the row is the return destination"
            ),
            Wiring(
                "SpacesSection+Remove.swift",
                "returningRow = neighbour",
                "a deletion lands on the next row, not the top"
            ),
        ]
        let files = try SourceScan.swiftSources(under: settingsDir)
        for wiring in wirings {
            let file = try #require(
                files.first {
                    $0.lastPathComponent == wiring.file
                },
                "\(wiring.file) is gone"
            )
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            #expect(
                source.contains(wiring.needle),
                Comment(
                    rawValue:
                        "\(wiring.file) lost `\(wiring.needle)` "
                        + "— \(wiring.why), and an unattached "
                        + "@FocusState moves focus nowhere while "
                        + "compiling cleanly"
                )
            )
        }
    }

    /// One focus wiring: the file it lives in, the use site that
    /// proves it, and why that site matters.
    private struct Wiring {
        let file: String
        let needle: String
        let why: String

        init(_ file: String, _ needle: String, _ why: String) {
            self.file = file
            self.needle = needle
            self.why = why
        }
    }
}
