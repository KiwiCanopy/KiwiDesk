import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The shadow rule (#1785), pure: Orion keeps an "Orion Preview"
/// beside every real window — no title-bar button, no AX child,
/// parked at 1×1 in the screen corner, reading `AXUnknown` as often
/// as `AXStandardWindow` (device, 2026-09-30). The rule must catch
/// that twin whatever its frame or subrole, and nothing a user
/// would call a window. What the loop does with the verdict is
/// `ShadowWindowTests`'.
@Suite("Shadow rule (#1785)")
struct ShadowRuleTests {
    private let frame = CGRect(x: 75, y: 86, width: 821, height: 1025)
    private let parked = CGRect(x: 0, y: 1116, width: 1, height: 1)

    private func traits(
        _ id: UInt32,
        buttons: Bool?,
        children: Int?,
        frame: CGRect? = nil
    ) -> WindowTraits {
        WindowTraits(
            id: WindowID(id),
            hasTitlebarButton: buttons,
            childCount: children,
            frame: frame ?? self.frame
        )
    }

    // MARK: - The reading

    @Test("a button or a child is content, whatever else failed")
    func contentNeedsOneAnswer() {
        #expect(ShellReading.of(button: true, children: nil) == .furnished)
        #expect(ShellReading.of(button: true, children: 0) == .furnished)
        #expect(ShellReading.of(button: false, children: 3) == .furnished)
        #expect(ShellReading.of(button: nil, children: 3) == .furnished)
    }

    @Test("a shell needs both reads answered")
    func shellNeedsBothAnswers() {
        #expect(ShellReading.of(button: false, children: 0) == .shell)
        #expect(ShellReading.of(button: nil, children: 0) == .unread)
        #expect(ShellReading.of(button: false, children: nil) == .unread)
        #expect(ShellReading.of(button: nil, children: nil) == .unread)
    }

    // MARK: - The rule

    @Test("a parked shell beside a real window is its shadow")
    func parkedTwinIsAShadow() {
        let host = traits(889_401, buttons: true, children: 6)
        let twin = traits(
            889_398,
            buttons: false,
            children: 0,
            frame: parked
        )
        #expect(
            WindowTraits.shadowHost(of: twin, among: [twin, host])
                == host.id
        )
    }

    @Test("a shell with nothing real beside it is a window")
    func shellAloneIsKept() {
        let frameless = traits(1, buttons: false, children: 0)
        #expect(
            WindowTraits.shadowHost(of: frameless, among: [frameless]) == nil
        )
    }

    @Test("the host on the shell's frame wins, then the one at its size")
    func nearestHostWins() {
        let elsewhere = traits(
            1,
            buttons: true,
            children: 6,
            frame: CGRect(x: 900, y: 86, width: 400, height: 300)
        )
        let sameSize = traits(
            2,
            buttons: true,
            children: 6,
            frame: frame.offsetBy(dx: 400, dy: 0)
        )
        let sameFrame = traits(3, buttons: true, children: 6)
        let twin = traits(4, buttons: false, children: 0)
        #expect(
            WindowTraits.shadowHost(
                of: twin,
                among: [elsewhere, sameSize, sameFrame]
            ) == sameFrame.id
        )
        #expect(
            WindowTraits.shadowHost(of: twin, among: [elsewhere, sameSize])
                == sameSize.id
        )
        #expect(
            WindowTraits.shadowHost(of: twin, among: [elsewhere])
                == elsewhere.id
        )
    }

    @Test("content, a button or an unanswered read keeps a window")
    func onlyAShellIsAShadow() {
        let host = traits(1, buttons: true, children: 6)
        let withContent = traits(2, buttons: false, children: 3)
        let withButton = traits(3, buttons: true, children: 0)
        let unread = traits(4, buttons: false, children: nil)
        let unasked = traits(5, buttons: nil, children: 0)
        for candidate in [withContent, withButton, unread, unasked] {
            #expect(
                WindowTraits.shadowHost(of: candidate, among: [host])
                    == nil,
                "w\(candidate.id.raw)"
            )
        }
    }

    @Test("only a buttoned window hosts")
    func hostNeedsAButton() {
        let twin = traits(1, buttons: false, children: 0)
        let shell = traits(2, buttons: false, children: 0)
        let content = traits(3, buttons: false, children: 4)
        let unread = traits(4, buttons: nil, children: 4)
        #expect(
            WindowTraits.shadowHost(
                of: twin,
                among: [twin, shell, content, unread]
            ) == nil
        )
    }
}
