import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `pocket` naming a window (#2678): it puts that window in, marking
/// it first under the capacity, and the bar menus' Pocket Window row
/// acts through it.
@Suite("Pocket a named window", .serialized)
@MainActor
struct PocketNamedTests {
    private let one = WindowID(1)
    private let two = WindowID(2)
    private let three = WindowID(3)

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-named-\(UUID().uuidString)")
        )
        for raw: UInt32 in [3, 2, 1] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 900_000 + pid_t(raw),
                        appName: "App\(raw)",
                        title: "Window \(raw)",
                        frame: CGRect(x: 100, y: 100, width: 600, height: 400)
                    )
                )
            )
        }
        core.handle(.windowFocused(three))
        return core
    }

    private func pocket(_ core: KiwiCore, _ id: WindowID) -> Bool {
        core.execute("pocket", args: [.number(Double(id.raw))]).isSuccess
    }

    @Test("a named window is marked and put in, the focus left alone")
    func namedGoesIn() {
        let core = makeCore()
        #expect(pocket(core, one))
        #expect(core.state.pocketPhase(of: one) == .pocketed)
        #expect(core.state.pocketPhase(of: three) == nil)
    }

    @Test("a named out window goes back; a pocketed one stays")
    func namedOutGoesBack() {
        let core = makeCore()
        #expect(pocket(core, one))
        core.execute("pocket")
        #expect(core.state.pocketPhase(of: one) == .out)
        #expect(pocket(core, one))
        #expect(core.state.pocketPhase(of: one) == .pocketed)
        #expect(pocket(core, one))
        #expect(core.state.pocketedWindows == [one])
    }

    @Test("One window refuses a second named window; Several takes it")
    func capacityGates() {
        let core = makeCore()
        #expect(pocket(core, one))
        #expect(!pocket(core, two))
        #expect(core.state.pocketPhase(of: two) == nil)
        core.execute("pocket.set_capacity", args: [.string("several")])
        #expect(pocket(core, two))
        #expect(core.state.pocketedWindows == [one, two])
    }

    @Test("an id no tracked window carries is refused")
    func unknownRefused() {
        let core = makeCore()
        #expect(!pocket(core, WindowID(77)))
        #expect(core.state.pocket.isEmpty)
    }

    @Test("the bar menu's Pocket Window row pockets its window")
    func menuRowPockets() throws {
        LocalizationManager.shared.select("en")
        let core = makeCore()
        let rows = core.windowRows([one], movable: false)
        let row = try #require(
            rows.first { $0.title == "Pocket Window" }
        )
        #expect(row.enabled)
        guard case .action(let perform) = row.kind else {
            Issue.record("Pocket Window is no action")
            return
        }
        perform()
        #expect(core.state.pocketPhase(of: one) == .pocketed)
        // Taken under One window: the next window's row greys.
        let next = core.windowRows([two], movable: false)
        #expect(next.first { $0.title == "Pocket Window" }?.enabled == false)
    }
}
