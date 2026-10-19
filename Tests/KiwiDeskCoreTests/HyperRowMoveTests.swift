import Foundation
import Testing

@testable import KiwiDeskCore

/// A row's own Move to Hyper (#2420): either base dropped with `⇧`
/// kept, the Desktop tier, `⌘`-only chords, `✦` rows and app chrome
/// offered nothing, and a held target refused naming its holder.
@Suite("Hyper move: one row at a time")
struct HyperRowMoveTests {
    private func row(_ combo: String, _ lua: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: .navigation)
    }

    private func move(
        _ combo: String,
        among others: [KeyBinding] = []
    ) -> HyperShortcutMove.RowMove? {
        let mover = row(combo, "KiwiDesk.mover()")
        return HyperShortcutMove.rowMove(mover, in: [mover] + others)
    }

    private func target(_ combo: String) -> String? {
        guard case .move(let to) = move(combo) else { return nil }
        return to
    }

    private func chord(_ combo: String) -> KeyCombo? {
        KeyCombo.parse(combo)
    }

    @Test("⌃⌥ and ⌥⌘ drop their base and keep ⇧")
    func basesDropShiftStays() {
        #expect(chord(target("control+option+p") ?? "") == chord("hyper+p"))
        #expect(
            chord(target("control+option+shift+p") ?? "")
                == chord("hyper+shift+p")
        )
        #expect(
            chord(target("option+command+left") ?? "")
                == chord("hyper+left")
        )
        #expect(
            chord(target("option+command+shift+1") ?? "")
                == chord("hyper+shift+1")
        )
    }

    @Test("the Desktop tier, ⌘ alone, ✦ rows and bare keys move nowhere")
    func offBothBasesIsNotOffered() {
        #expect(move("control+option+shift+command+1") == nil)
        #expect(move("control+option+command+p") == nil)
        #expect(move("command+p") == nil)
        #expect(move("option+p") == nil)
        #expect(move("hyper+p") == nil)
        #expect(move("hyper+control+option+p") == nil)
        #expect(move("f5") == nil)
    }

    @Test("app chrome keeps its chord")
    func chromeIsNotOffered() {
        for chrome in DefaultKeybindings.appChromeRows() {
            #expect(
                HyperShortcutMove.rowMove(chrome, in: [chrome]) == nil
            )
        }
        for side in KiwiHubSide.allCases {
            let hub = row("control+option+j", side.lua)
            #expect(HyperShortcutMove.rowMove(hub, in: [hub]) == nil)
        }
    }

    @Test("a held target refuses and names its holder")
    func heldTargetNamesHolder() {
        let holder = row("hyper+shift+p", "KiwiDesk.holder()")
        let other = row("control+option+q", "KiwiDesk.other()")
        let verdict = move("control+option+shift+p", among: [other, holder])
        guard case .taken(let to, let by) = verdict else {
            Issue.record("expected a refusal: \(String(describing: verdict))")
            return
        }
        #expect(chord(to) == chord("hyper+shift+p"))
        #expect(by == holder)
    }

    @Test("the row's own chord never holds its target")
    func ownRowIsNotTheHolder() {
        let other = row("control+option+q", "KiwiDesk.other()")
        let expected = target("control+option+p") ?? ""
        #expect(!expected.isEmpty)
        #expect(
            move("control+option+p", among: [other])
                == .move(to: expected)
        )
    }
}
