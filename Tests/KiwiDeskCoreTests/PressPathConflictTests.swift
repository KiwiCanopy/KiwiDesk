import Testing

@testable import KiwiDeskCore

/// A system-shortcut conflict names the door the row's press comes
/// through (#3311), read from the sort the manager arms from
/// (`KeyboardTapArming`), on both conflict doors.
@Suite("The press path of a system-shortcut conflict (#3311)")
struct PressPathConflictTests {
    private func row(_ id: String, _ combo: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: "print(\"\(id)\")")
    }

    private func path(
        of binding: KeyBinding,
        in rows: [KeyBinding],
        sides: Bool
    ) -> PressPath? {
        let found = KeybindingConflicts.conflict(
            for: binding,
            in: rows,
            distinguishingSides: sides
        )
        let layer = KeybindingConflicts.rowConflicts(
            of: rows,
            distinguishingSides: sides
        )[binding.id]
        guard case .systemShortcut(_, let one)? = found?.target,
            case .systemShortcut(_, let other)? = layer?.target
        else { return nil }
        #expect(one == other)
        return one
    }

    @Test("a leader is the tap's; a press row and a Hyper row Carbon's")
    func leaderAndPressRow() {
        let leader = KeyBinding(combo: "cmd+space", kind: .sequence)
        #expect(path(of: leader, in: [leader], sides: false) == .keyboardTap)
        let press = row("a", "cmd+space")
        #expect(path(of: press, in: [press], sides: true) == .carbon)
        let hyper = row("h", "hyper+cmd+space")
        #expect(path(of: hyper, in: [hyper], sides: true) == .carbon)
    }

    @Test("a sided row is the tap's only while sides are told apart")
    func sidedRow() {
        let sided = row("a", "rcmd+space")
        #expect(path(of: sided, in: [sided], sides: true) == .keyboardTap)
        #expect(path(of: sided, in: [sided], sides: false) == .carbon)
    }

    @Test("the either-side row beside a sided one moves to the tap")
    func eitherSideTwin() {
        let sided = row("a", "rcmd+space")
        let plain = row("b", "cmd+space")
        #expect(
            path(of: plain, in: [sided, plain], sides: true) == .keyboardTap
        )
        #expect(path(of: plain, in: [plain], sides: true) == .carbon)
    }

    @Test("the tap takes exactly the chords measured on it")
    func verdicts() {
        let tap = SystemShortcut.allCases.filter {
            $0.losesToKiwiDesk(on: .keyboardTap)
        }
        #expect(
            Set(tap) == [
                .spotlight, .finderSearch, .missionControl, .appWindows,
                .screenshot, .screenshotSelection, .screenshotTools,
                .missionControlSpaceLeft, .missionControlSpaceRight,
                .appSwitcher, .dockHiding, .inputSourceNext,
            ]
        )
    }
}
