import AppKit
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

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
        if !stuck { hosted = nil }
    }
}

@MainActor
private final class FakeKeeper: QuitSheetKeeper {
    var keeps: Set<ObjectIdentifier> = []
    var refusals = 0

    func keepsSheet(on window: NSWindow) -> Bool {
        keeps.contains(ObjectIdentifier(window))
    }

    func quitRefused() { refusals += 1 }
}

@MainActor
private final class QuitRegistrar: HotkeyRegistrar {
    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? { 1 }
    func unregister(id: UInt32) {}
}

/// A quit, restart or logout closes a confirmation as Cancel and
/// keeps asking only for the sheet guarding unsaved Settings work
/// (#2049 ruling). The wiring that routes every quit here is
/// `QuitSheetsWiringTests`'.
@Suite("Quit closes confirmations (#2049)")
@MainActor
struct QuitSheetsTests {
    @Test("a confirmation ends as Cancel and the quit proceeds")
    func confirmationEndsAsCancel() {
        let window = FakeHost("settings")
        let dialog = FakeHost("dialog")
        window.attach(dialog)
        let keeper = FakeKeeper()
        let proceeds = QuitSheets.clear([window], keeper: keeper)
        #expect(proceeds)
        #expect(window.hosted == nil)
        #expect(window.ended.count == 1)
        #expect(window.ended.first?.0 === dialog)
        #expect(window.ended.first?.1 == .cancel)
        #expect(keeper.refusals == 0)
    }

    @Test("a kept sheet stays, refuses the quit and is shown")
    func guardKeepsAsking() {
        let settings = FakeHost("settings")
        let discard = FakeHost("discard")
        settings.attach(discard)
        let other = FakeHost("other")
        let about = FakeHost("about")
        other.attach(about)
        let keeper = FakeKeeper()
        keeper.keeps = [ObjectIdentifier(settings)]
        let proceeds = QuitSheets.clear(
            [settings, other],
            keeper: keeper
        )
        #expect(!proceeds)
        #expect(settings.hosted === discard)
        #expect(settings.ended.isEmpty)
        // Another window's confirmation still closes.
        #expect(other.hosted == nil)
        #expect(keeper.refusals == 1)
    }

    @Test("no keeper keeps nothing")
    func noKeeperClearsAll() {
        let window = FakeHost("window")
        window.attach(FakeHost("dialog"))
        #expect(QuitSheets.clear([window], keeper: nil))
        #expect(window.hosted == nil)
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
        #expect(QuitSheets.clear([window, outer], keeper: nil))
        #expect(order == ["inner", "outer"])
    }

    @Test("a sheet that will not leave ends the loop")
    func stuckSheetStops() {
        let window = FakeHost("window")
        window.attach(FakeHost("dialog"))
        window.stuck = true
        #expect(QuitSheets.clear([window], keeper: nil))
        #expect(window.ended.count == 1)
    }

    @Test("only the discard gate keeps asking")
    func discardGateIsTheGuard() throws {
        LocalizationManager.shared.select("en")
        let core = makeTestCore(hotkeyRegistrar: QuitRegistrar())
        try core.saveGuiConfig(GuiConfig())
        let model = makeTestModel(core: core)
        #expect(!model.quitKeepsAsking)
        model.confirmingProfileDelete("Work") {}
        #expect(!model.quitKeepsAsking)
        model.cancelPendingDiscard()
        model.config.settings.gapsGlobal.inner.horizontal += 7
        model.confirmingProfileDelete("Work") {}
        // A delete's confirm closes even over unsaved work.
        #expect(!model.quitKeepsAsking)
        model.cancelPendingDiscard()
        model.discardingEdits(message: "m", confirmLabel: "c") {}
        #expect(model.quitKeepsAsking)
        model.cancelPendingDiscard()
        #expect(!model.quitKeepsAsking)
    }
}
