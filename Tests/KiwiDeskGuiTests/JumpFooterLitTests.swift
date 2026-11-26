import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// KiwiHub's footer lights every press live now (#3667, amending
/// #2246): the pick, the chords the held keys complete, and the
/// side switch, last on every side, wherever Tab steps a side.
/// Each expected set is the ruling's table, stated apart from the
/// code.
@MainActor
@Suite("KiwiHub footer lit hints (#3667)")
struct JumpFooterLitTests {
    private static let outside = DesktopsStateTests.state(
        DesktopsStateTests.overview()
    )

    private static var inside: DesktopsState {
        var state = outside
        _ = state.press(.openSpace, repeated: false)
        return state
    }

    private func desktops(
        _ state: DesktopsState,
        _ held: NSEvent.ModifierFlags = []
    ) -> JumpFooter {
        JumpFooter(
            scope: .desktops,
            modifiers: held,
            desktops: DesktopsFooterState(state)
        )
    }

    private func windows(_ held: NSEvent.ModifierFlags = []) -> JumpFooter {
        JumpFooter(
            scope: .windows,
            modifiers: held,
            stripSteps: true,
            lastAppCombo: KeyCombo.parse("option+tab")
        )
    }

    private func previous(_ scope: JumpScope) -> String {
        "⇧⇥ " + scope.stepped(forward: false).title
    }

    private func next(_ scope: JumpScope) -> String {
        "⇥ " + scope.stepped(forward: true).title
    }

    @Test("Desktops outside a Space lights what each chord does")
    func desktopsOutside() throws {
        LocalizationManager.shared.select("en")
        let state = Self.outside
        try #require(DesktopsFooterState(state).digits > 0)
        // Jump · Move window there · Open Space · digits · ⇥.
        let cases: [(NSEvent.ModifierFlags, Set<Int>)] = [
            ([], [0, 4]), (.shift, [1, 4]), (.option, []),
            (.command, [2, 3]), ([.shift, .command], [3]),
            ([.option, .command], []), ([.shift, .option], []),
        ]
        for (held, lit) in cases {
            #expect(desktops(state, held).lit == lit, "\(held)")
        }
        let shifted = desktops(state, .shift).hints
        #expect(shifted.last == previous(.desktops))
        // ⇧ alone still rewrites the digits, unlit (owner).
        #expect(shifted[3].hasPrefix("⇧⌘1"))
        #expect(desktops(state, .option).hints.last == next(.desktops))
    }

    @Test("Desktops inside a Space lights what each chord does")
    func desktopsInside() {
        LocalizationManager.shared.select("en")
        let state = Self.inside
        // Jump · Move/Swap here · Pick up · ⌘↑ Back · ⇥.
        let cases: [(NSEvent.ModifierFlags, Set<Int>)] = [
            ([], [0, 4]), (.shift, [1, 4]), (.option, [1]),
            ([.shift, .option], [1]), (.command, [2, 3]),
            ([.shift, .command], []), ([.option, .command], []),
        ]
        for (held, lit) in cases {
            #expect(desktops(state, held).lit == lit, "\(held)")
        }
    }

    @Test("a carry ends in the side switch, and ⌘ lights Back")
    func desktopsCarrying() throws {
        LocalizationManager.shared.select("en")
        var state = Self.inside
        let window = try #require(state.window)
        #expect(state.togglePick(window) == nil)
        let rest = desktops(state)
        // Drop · Drop & follow · Cancel · Put back · Back · ⇥.
        #expect(rest.hints.count == 6)
        #expect(rest.hints.last == next(.desktops))
        #expect(rest.lit == [0, 5])
        #expect(desktops(state, .shift).lit == [5])
        #expect(desktops(state, .option).lit == [])
        #expect(desktops(state, .command).lit == [3, 4])
        // Carried out of the Space: Drop · ⌃↩ · Esc · digits · ⇥.
        _ = state.press(.leaveSpace, repeated: false)
        let out = desktops(state)
        #expect(out.hints.count == 5)
        #expect(out.hints.last == next(.desktops))
        #expect(out.lit == [0, 4])
        #expect(desktops(state, .command).lit == [3])
        #expect(desktops(state, [.shift, .command]).lit == [])
    }

    @Test("Windows puts ⇥ last and lights the opener under ⌥")
    func windowsOrderAndOpener() {
        LocalizationManager.shared.select("en")
        // Jump · Move · Swap · digits · Apps · Next app · ⇥.
        let rest = windows()
        #expect(
            rest.hints.suffix(3) == [
                "← → Apps", "⌥⇥ Next app", next(.windows),
            ]
        )
        #expect(rest.lit == [0, 6])
        #expect(windows(.option).lit == [2, 5])
        #expect(windows(.option).hints.last == next(.windows))
        let shifted = windows(.shift)
        #expect(shifted.hints.last == previous(.windows))
        #expect(shifted.lit == [1, 6])
        let back = windows([.shift, .option])
        #expect(back.hints[5] == "⌥⇧⇥ Previous app")
        #expect(back.lit == [2, 5])
        #expect(windows(.command).lit == [3])
    }

    @Test("an unbound opener draws and lights no entry")
    func windowsWithoutOpener() {
        LocalizationManager.shared.select("en")
        let footer = JumpFooter(
            scope: .windows,
            modifiers: [.shift, .option],
            stripSteps: true
        )
        #expect(!footer.hints.contains { $0.contains("app") })
        #expect(footer.lit == [2])
    }

    @Test("the opener lights only for a chord the keys can press")
    func openerChords() {
        LocalizationManager.shared.select("en")
        func footer(
            _ combo: String,
            _ held: NSEvent.ModifierFlags,
            selection: Bool = true
        ) -> JumpFooter {
            JumpFooter(
                scope: .windows,
                modifiers: held,
                hasSelection: selection,
                lastAppCombo: KeyCombo.parse(combo)
            )
        }
        // A tap or a ✦ chord is drawn but never lit.
        #expect(footer("rcmd", [.command]).lit == [3])
        #expect(footer("hyper+tab", []).lit == [0, 5])
        // ⌃ is read for the opener as the panel reads it; the other
        // hints' ⌃ reading is #3677's.
        let control = footer("ctrl+option+tab", [.control, .option])
        #expect(control.lit.contains(4))
        // The opener acts with nothing selected.
        #expect(footer("option+tab", .option, selection: false).lit == [4])
    }

    @Test("the side switch is the last hint everywhere")
    func sideSwitchIsLast() throws {
        LocalizationManager.shared.select("en")
        var carrying = Self.inside
        let window = try #require(carrying.window)
        _ = carrying.togglePick(window)
        var footers = [windows(), JumpFooter(scope: .shortcuts)]
        footers.append(JumpFooter(scope: .view))
        footers.append(JumpFooter(scope: .view, naming: true))
        for state in [Self.outside, Self.inside, carrying] {
            footers.append(desktops(state))
        }
        for footer in footers {
            for held in JumpFooter.heldStates {
                let shown = footer.holding(held)
                #expect(
                    shown.hints.last == shown.sideHint(held),
                    "\(footer.scope) \(held)"
                )
            }
        }
    }

    @Test("a line fits on its widest held state on every side")
    func fitIsStable() throws {
        let chrome = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Jump/JumpPanelChrome.swift"
                )
        )
        .split(whereSeparator: \.isWhitespace).joined()
        #expect(chrome.contains("reversed(),id:\\.self){stable($0)}"))
        #expect(
            chrome.contains(
                "ForEach(Self.heldStates,id:\\.rawValue){heldin"
                    + "letfooter=holding(held)"
                    + "footer.row(Array(footer.hints.prefix(shown))).hidden()}"
            )
        )
    }

    @Test("the Windows line sheds Next app, then ⇥, then Apps")
    func windowsShedOrder() {
        LocalizationManager.shared.select("en")
        let slots = windows().windowsSlots(held: [])
        #expect(JumpFooter.kept(slots, shown: nil) == Array(0...6))
        #expect(JumpFooter.kept(slots, shown: 6) == [0, 1, 2, 3, 4, 6])
        #expect(JumpFooter.kept(slots, shown: 5) == [0, 1, 2, 3, 4])
        #expect(JumpFooter.kept(slots, shown: 4) == [0, 1, 2, 3])
        #expect(JumpFooter.kept(slots, shown: 3) == [0, 1, 2])
        let drawn = windows().windowsDrawn(held: [], level: 0, shown: 6)
        #expect(drawn.last == next(.windows))
    }

    @Test("⇥ lights on Shortcuts and with nothing selected")
    func tabNeedsNoSelection() {
        LocalizationManager.shared.select("en")
        let shortcuts = JumpFooter(scope: .shortcuts, hasSelection: false)
        #expect(shortcuts.lit == [0])
        let shifted = JumpFooter(scope: .shortcuts, modifiers: .shift)
        #expect(shifted.hints == [previous(.shortcuts)])
        #expect(shifted.lit == [0])
        let view = JumpFooter(scope: .view, hasSelection: false)
        #expect(view.lit == [view.hints.count - 1])
    }

    @Test("the panel hands the footer the opener as bound")
    func openerWiring() throws {
        func read(_ name: String) throws -> String {
            try SourceScan.strippedSource(
                at: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent("Sources/KiwiDesk/Jump")
                    .appendingPathComponent(name)
            )
            .split(whereSeparator: \.isWhitespace).joined()
        }
        let needle = "model.lastAppCombo=lastAppCombo()"
        #expect(try read("JumpPanelController.swift").contains(needle))
        #expect(
            try read("JumpPanelController+Shortcuts.swift").contains(needle)
        )
        #expect(
            try read("JumpPanelView+Footer.swift")
                .contains("lastAppCombo:model.lastAppCombo")
        )
    }
}
