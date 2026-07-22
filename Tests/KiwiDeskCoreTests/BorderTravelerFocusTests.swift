import Foundation
import Testing

@testable import KiwiDeskCore

/// The focus ring follows a tiled-sticky traveler the same way the
/// App Bar / Scrolling / Monocle do (#431 `focusAnchor`, extended to
/// borders): a keyboard focus that lands on a traveler must move the
/// ring onto it, not only a mouse click. A traveler can never be the
/// active space's membership-guarded `focused` slot, so the ring was
/// picking `space.focused` and never surfaced it.
@MainActor
@Suite("Border traveler focus", .serialized)
struct BorderTravelerFocusTests {

    private func makeCore() -> KiwiCore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        return KiwiCore(configDirectory: directory)
    }

    private func makeWindow(
        _ id: UInt32,
        isSticky: Bool = false
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: 100,
            appName: "App",
            title: "Title",
            stickyScope: isSticky ? .global : .none
        )
    }

    /// space1 (active) holds locals 1...2; a sticky window homes on
    /// space2 and so travels into space1's row.
    private func seed(_ core: KiwiCore) {
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.state.workspaces.activate("1")
        for id: UInt32 in 1...2 {
            core.state.windows.upsert(makeWindow(id))
            core.state.workspaces.add(WindowID(id), to: "1")
        }
        core.state.windows.upsert(makeWindow(50, isSticky: true))
        core.state.workspaces.add(WindowID(50), to: "2")
    }

    @Test("A focused traveler wears the focused ring")
    func travelerGetsFocusedRing() {
        let core = makeCore()
        seed(core)
        // Focusing the traveler lands on its HOME space and sets the
        // system focus, never space1's own slot.
        core.state.workspaces.focus(WindowID(50), in: "2")
        let specs = core.desiredBorderSpecs()
        let focusColor = core.tiler.settings.borderStyle.focusedColor
        // The lone ring (unfocused borders default off) is the
        // traveler, in the focused colour.
        #expect(specs.count == 1)
        #expect(specs.first?.window == WindowID(50))
        #expect(specs.first?.colorHex == focusColor)
    }

    @Test("A focused local keeps the ring on the local window")
    func localKeepsRing() {
        let core = makeCore()
        seed(core)
        core.state.workspaces.focus(WindowID(50), in: "2")
        core.state.workspaces.focus(WindowID(1), in: "1")
        let specs = core.desiredBorderSpecs()
        #expect(specs.count == 1)
        #expect(specs.first?.window == WindowID(1))
    }
}
