import CoreGraphics
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
        return makeTestCore(configDirectory: directory)
    }

    private func makeWindow(
        _ id: UInt32,
        isSticky: Bool = false,
        isFloating: Bool = false
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: 100,
            appName: "App",
            title: "Title",
            frame: CGRect(x: 100, y: 100, width: 400, height: 300),
            isFloating: isFloating,
            stickyScope: isSticky ? .global : .none
        )
    }

    /// space1 (active) holds locals 1...2; a sticky window homes on
    /// space2 and so travels into space1's row.
    private func seed(_ core: KiwiCore) {
        core.tiler.settings.borderStyle.unfocusedEnabled = false
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

    /// #2259: the anchor admits a FLOATING sticky window visiting
    /// the active space, so the ring slots must too — or the focus
    /// lands on a window with no slot and every ring goes dormant.
    @Test("A focused floating sticky visitor wears the focused ring")
    func floatingVisitorGetsFocusedRing() {
        let core = makeCore()
        seed(core)
        core.state.windows.upsert(
            makeWindow(60, isSticky: true, isFloating: true)
        )
        core.state.workspaces.add(WindowID(60), to: "2")
        core.state.workspaces.focus(WindowID(60), in: "2")
        let specs = core.desiredBorderSpecs()
        let focusColor = core.tiler.settings.borderStyle.focusedColor
        #expect(specs.count == 1)
        #expect(specs.first?.window == WindowID(60))
        #expect(specs.first?.colorHex == focusColor)
    }

    /// #2259, the unfocused arm: a floating sticky visitor is a float,
    /// so it takes the unfocused ring every float gets (#1286).
    @Test("An unfocused floating sticky visitor wears the unfocused ring")
    func floatingVisitorGetsUnfocusedRing() {
        let core = makeCore()
        seed(core)
        core.tiler.settings.borderStyle.unfocusedEnabled = true
        core.state.windows.upsert(
            makeWindow(60, isSticky: true, isFloating: true)
        )
        core.state.workspaces.add(WindowID(60), to: "2")
        core.state.workspaces.focus(WindowID(1), in: "1")
        let style = core.tiler.settings.borderStyle
        let drawn = Dictionary(
            uniqueKeysWithValues: core.desiredBorderSpecs().map {
                ($0.window, $0.colorHex)
            }
        )
        #expect(drawn[WindowID(1)] == style.focusedColor)
        #expect(drawn[WindowID(60)] == style.unfocusedColor)
    }
}
