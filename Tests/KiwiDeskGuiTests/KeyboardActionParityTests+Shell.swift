import Foundation
import Testing

/// The SHELL's own two focus statements — the pair gui.md cites
/// as the exemplars of "every shape change states a focus
/// destination", and the only wirings in the tree that had no
/// needle at all until #998 (a push focuses the back chip; a
/// return restores `nav.homeReturnFocus`).
///
/// Split from `KeyboardActionParityTests.swift` under the §2.1
/// ceiling, same suite. Per-file private helpers are the
/// convention, so the small wiring/squash pair below is a
/// deliberate copy of that file's.
///
/// The raise needle spans the WHOLE `onChange` closure,
/// including its key: #998 shipped as a wiring keyed on
/// `destination != nil`, which fires on Home→area and never on
/// area→area (a cross-reference, a search pick into another
/// area) — so the raise existed, read as correct, and stated no
/// destination on one navigation path. A needle on the
/// assignment alone would have stayed green through exactly
/// that.
///
/// The raise needle carries its NEIGHBOUR — `.onExitCommand` —
/// for the same reason it carries its key. Naming the file alone
/// says the closure is somewhere in `SettingsView.swift`, and
/// `guard-prover` (2026-09-01) showed the cost: moved onto the
/// `selection == nil` branch, the raise fires from the subtree
/// the Home→area transition is tearing down, states nothing on
/// exactly that navigation, and the guard stayed green. The
/// neighbour pins it to `structuredShell`'s own chain, which is
/// the view that outlives both branches. Reordering that chain
/// reds this on purpose: read the message, do not chase the
/// bytes.
///
/// The push pair moved out of `SettingsHeaderBar` in #996: the
/// destination is the content pane, so the raise has to live on
/// `structuredShell` rather than on the pane it focuses —
/// `onChange` does not fire on a view's first appearance, and
/// the pane is CREATED by the Home→area transition, so the same
/// closure hung there would state nothing on exactly the
/// navigation #998 was about. The needle names the shell file
/// for that reason, and moving it back is the regression.
extension KeyboardActionParityTests {
    @Test("the shell states its two focus destinations")
    func shellStatesItsFocusDestinations() throws {
        let wirings: [ShellWiring] = [
            ShellWiring(
                "SettingsView+Detail.swift",
                ".focusable() .focused($contentFocused)",
                "the content pane is the push destination (#996) "
                    + "— and BOTH halves: an unattached "
                    + "@FocusState moves focus nowhere, and a "
                    + "container that never took `.focusable()` "
                    + "cannot be assigned to in the first place, "
                    + "which is the half a Button gave free"
            ),
            ShellWiring(
                "SettingsView.swift",
                ".onExitCommand { if selection != nil "
                    + "{ selection = nil } } "
                    + ".onChange(of: model.destination) { _, now in "
                    + "if now != nil, "
                    + "model.nav.navigationFromKeyboard "
                    + "{ contentFocused = true } }",
                "and the raise is keyed on the VALUE: keyed on "
                    + "`destination != nil` it fires on Home→area "
                    + "only, so an area→area navigation destroys "
                    + "the focused subtree and states nothing "
                    + "(#998) — and it is GATED on the input "
                    + "source, or a mouse click draws a focus "
                    + "ring macOS would not have drawn (#991)"
            ),
            ShellWiring(
                "HomeScreen.swift",
                ".focused($focusedCard, equals: destination)",
                "a Home card is the return destination"
            ),
            ShellWiring(
                "HomeScreen.swift",
                "model.nav.homeReturnFocus = destination",
                "the push records which card to return to — "
                    + "without it the restore reads nil forever"
            ),
            ShellWiring(
                "HomeScreen.swift",
                "if let last = model.nav.homeReturnFocus { "
                    + "if model.nav.navigationFromKeyboard { "
                    + "focusedCard = last } "
                    + "model.nav.homeReturnFocus = nil }",
                "and the return pays it, once — the whole "
                    + "closure, so clearing the slot stays beside "
                    + "the restore rather than leaking a stale "
                    + "card into the next unrelated appear, and "
                    + "the clear stays OUTSIDE the input-source "
                    + "gate: a mouse pop must not restore focus, "
                    + "but it must still empty the slot (#991)"
            ),
            ShellWiring(
                "SettingsModel.swift",
                "didSet { nav.navigationFromKeyboard = "
                    + "SettingsInputSource.isKeyboard }",
                "and the input source is recorded where every "
                    + "navigation path already passes — the "
                    + "destination write itself — so a path added "
                    + "later cannot forget it, and the read "
                    + "happens while macOS is still dispatching "
                    + "the event that caused the navigation "
                    + "(#991)"
            ),
        ]
        let dir = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        let files = try SourceScan.swiftSources(under: dir)
        for wiring in wirings {
            let file = try #require(
                files.first {
                    $0.lastPathComponent == wiring.file
                },
                "\(wiring.file) is gone"
            )
            let source = squashedShell(
                SourceScan.stripComments(
                    try String(contentsOf: file, encoding: .utf8)
                )
            )
            #expect(
                source.contains(squashedShell(wiring.needle)),
                Comment(
                    rawValue:
                        "\(wiring.file) lost `\(wiring.needle)` "
                        + "— \(wiring.why), and the failure is "
                        + "silent to everything except a person "
                        + "using the keyboard"
                )
            )
        }
    }
}

/// Whitespace-free source, so a needle survives the formatter
/// wrapping a call across lines — this file's copy of the main
/// file's private `squashed` (per-file helpers, tests.md).
private func squashedShell(_ source: String) -> String {
    source.split(whereSeparator: \.isWhitespace).joined()
}

/// One focus wiring: file, use-site needle, and why it matters.
private struct ShellWiring {
    let file: String
    let needle: String
    let why: String

    init(_ file: String, _ needle: String, _ why: String) {
        self.file = file
        self.needle = needle
        self.why = why
    }
}
