import AppKit
import Testing

@testable import KiwiDesk

/// A never-shown window whose sheet is a stored value: AppKit
/// attaches a real sheet only to a visible window, and a test
/// orders nothing on screen.
@MainActor
private final class FakeHost: NSWindow {
    var hosted: FakeHost?
    weak var parentHost: FakeHost?
    /// A sheet that will not leave when ended.
    var stuck = false
    var ended: [(FakeHost, NSApplication.ModalResponse)] = []
    var journal: (String) -> Void = { _ in }
    let name: String

    init(_ name: String) {
        self.name = name
        super.init(
            contentRect: .zero,
            styleMask: [],
            backing: .buffered,
            defer: true
        )
        isReleasedWhenClosed = false
    }

    func attach(_ child: FakeHost) {
        hosted = child
        child.parentHost = self
    }

    override var attachedSheet: NSWindow? { hosted }
    override var sheetParent: NSWindow? { parentHost }

    override func endSheet(
        _ sheetWindow: NSWindow,
        returnCode: NSApplication.ModalResponse
    ) {
        guard let child = sheetWindow as? FakeHost else { return }
        ended.append((child, returnCode))
        journal(child.name)
        // A stuck sheet lets go after a few tries, so a clear
        // that loops on it reds the count instead of hanging.
        if !stuck || ended.count >= 8 { hosted = nil }
    }
}

/// A quit, restart or logout closes every open sheet as Cancel,
/// the Settings dialogs included (#2049 ruling). The wiring that
/// routes every quit here is `QuitSheetsWiringTests`'.
@Suite("Quit closes every sheet (#2049)")
@MainActor
struct QuitSheetsTests {
    @Test("every window's sheet ends as Cancel")
    func sheetsEndAsCancel() {
        let window = FakeHost("settings")
        let dialog = FakeHost("dialog")
        window.attach(dialog)
        let other = FakeHost("other")
        let about = FakeHost("about")
        other.attach(about)
        QuitSheets.clear([window, other])
        #expect(window.hosted == nil)
        #expect(window.ended.count == 1)
        #expect(window.ended.first?.0 === dialog)
        #expect(window.ended.first?.1 == .cancel)
        #expect(other.hosted == nil)
        #expect(other.ended.first?.0 === about)
    }

    @Test("a nested sheet ends before its parent sheet")
    func innermostFirst() {
        var order: [String] = []
        let window = FakeHost("window")
        let outer = FakeHost("outer")
        let inner = FakeHost("inner")
        window.attach(outer)
        outer.attach(inner)
        window.journal = { order.append($0) }
        outer.journal = { order.append($0) }
        // The sheet itself is listed too, as `NSApp.windows` does.
        QuitSheets.clear([window, outer])
        #expect(order == ["inner", "outer"])
    }

    @Test("a sheet that will not leave ends the loop")
    func stuckSheetStops() {
        let window = FakeHost("window")
        window.attach(FakeHost("dialog"))
        window.stuck = true
        QuitSheets.clear([window])
        #expect(window.ended.count == 1)
    }
}
