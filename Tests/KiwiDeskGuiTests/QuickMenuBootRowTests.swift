import AppKit
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Fake menu-bar slot carrying a REAL button, so the icon's
/// starting state is observable: `appearsDisabled` and the
/// accessibility name are the whole signal (#802), and a nil
/// button — the convention for the menu-only suites — makes
/// `render()` return before drawing anything. Constructed
/// directly, never through `NSStatusBar.system`, which is the
/// touch `StatusItemSeamGuardTests` seals.
@MainActor
private final class FakeStatusItem: StatusItemHandle {
    let button: NSStatusBarButton? = NSStatusBarButton()
    var menu: NSMenu?
}

/// The quick menu and the status mark while boot is still
/// scanning (#802).
///
/// The acceptance criterion behind this is #801's: the menu opens
/// at any point after launch. That makes the menu the surface
/// that has to be honest — it is now reachable in a state where
/// half of what it offers cannot work yet, and a menu that opens
/// instantly onto rows that silently do nothing is the same
/// broken read with a costume on.
///
/// `.serialized` because `LocalizationManager` is a process-wide
/// singleton (titles are matched in English).
@Suite("Quick menu boot readiness (#802)", .serialized)
@MainActor
struct QuickMenuBootRowTests {
    private func controller(
        phase: BootPhase,
        warning: Bool = false,
        configError: Bool = false
    ) -> StatusItemController {
        LocalizationManager.shared.select("en")
        let controller = StatusItemController(
            item: FakeStatusItem()
        )
        controller.profilesProvider = {
            (active: "Work", all: ["Work", "Play"], broken: [])
        }
        controller.setWarning(warning)
        controller.setConfigError(configError)
        controller.setBootPhase(phase)
        return controller
    }

    private func menu(
        _ controller: StatusItemController
    ) -> NSMenu {
        let menu = NSMenu()
        controller.menuNeedsUpdate(menu)
        return menu
    }

    private func row(
        _ menu: NSMenu,
        titled title: String
    ) -> NSMenuItem? {
        menu.items.first { $0.title == title }
    }

    private func startingRow(_ menu: NSMenu) -> NSMenuItem? {
        menu.items.first {
            $0.title.hasPrefix("Starting up")
        }
    }

    @Test("the starting row states the live count")
    func startingRowStatesTheCount() {
        let controller = controller(
            phase: .scanning(scanned: 51, total: 109)
        )

        let row = startingRow(menu(controller))

        // A determinate count in words — the count is what makes
        // the wait read as working rather than broken.
        #expect(row?.title == "Starting up — apps: 51 of 109")
        // Context only, never an action.
        #expect(row?.isEnabled == false)
    }

    @Test("an open menu's count is retitled per chunk")
    func openMenuCountIsLive() {
        let controller = controller(
            phase: .scanning(scanned: 2, total: 109)
        )
        let menu = NSMenu()
        controller.menuNeedsUpdate(menu)
        #expect(
            startingRow(menu)?.title
                == "Starting up — apps: 2 of 109"
        )

        controller.setBootPhase(.scanning(scanned: 40, total: 109))

        // The row is built once per open, and on a heavy session
        // the menu is open for most of the boot it reports — a
        // snapshot would sit at "2 of 109" for as long as the user
        // held it (owner, on device, 2026-08-12).
        #expect(
            startingRow(menu)?.title
                == "Starting up — apps: 40 of 109"
        )

        // Ready ends the row's life rather than retitling it: the
        // rank changed, so the whole menu is rebuilt on next open.
        controller.setBootPhase(.ready)
        #expect(!controller.starting)
    }

    @Test("the row is gone once boot is ready")
    func noRowWhenReady() {
        let ready = menu(controller(phase: .ready))
        #expect(startingRow(ready) == nil)
        // And the fence with it: the warning slot is derived from
        // presence, so a healthy menu opens straight on Layout.
        #expect(ready.items.first?.isSeparatorItem == false)
    }

    @Test("Layout and Switch Profile grey while starting")
    func actionsGreyWhileStarting() {
        let starting = menu(
            controller(phase: .scanning(scanned: 2, total: 9))
        )
        // Grey, don't hide (#171): both act on state the scan has
        // not finished collecting, and both work in a moment.
        #expect(row(starting, titled: "Layout")?.isEnabled == false)
        #expect(
            row(starting, titled: "Switch Profile")?.isEnabled
                == false
        )

        let ready = menu(controller(phase: .ready))
        #expect(row(ready, titled: "Layout")?.isEnabled == true)
        #expect(
            row(ready, titled: "Switch Profile")?.isEnabled == true
        )
    }

    @Test("a missing permission still outranks a boot in flight")
    func permissionOutranksStarting() {
        let controller = controller(
            phase: .scanning(scanned: 1, total: 9),
            warning: true,
            configError: true
        )

        let items = menu(controller).items
        let titles = items.map(\.title)
        let paused = titles.firstIndex {
            $0.hasPrefix("Window Management Paused")
        }
        let starting = titles.firstIndex {
            $0.hasPrefix("Starting up")
        }
        let issues = titles.firstIndex {
            $0.hasPrefix("Config Issues")
        }

        // Without Accessibility nothing works however far a boot
        // got; a config problem is a thing to fix once the app can
        // be clicked at all. The icon ranks these three the same
        // way — `statusMarkRanksTheStartingState` below.
        #expect(paused != nil)
        #expect(starting != nil)
        #expect(issues != nil)
        if let paused, let starting, let issues {
            #expect(paused < starting)
            #expect(starting < issues)
        }
    }

    // MARK: - The mark itself

    @Test("the mark dims while starting and returns after")
    func statusMarkDimsWhileStarting() {
        let controller = controller(
            phase: .scanning(scanned: 1, total: 9)
        )
        let button = controller.anchorButton
        #expect(button != nil)

        #expect(controller.starting)
        #expect(button?.appearsDisabled == true)
        // Lightness is the signal, so the glyph itself must not
        // change — a second glyph would be a new vocabulary for
        // one transient state.
        #expect(button?.image != nil)
        #expect(
            button?.accessibilityLabel() == "KiwiDesk (starting up)"
        )

        controller.setBootPhase(.ready)

        #expect(!controller.starting)
        #expect(button?.appearsDisabled == false)
        #expect(button?.accessibilityLabel() == "KiwiDesk")
    }

    @Test("the mark ranks starting under the permission warning")
    func statusMarkRanksTheStartingState() {
        let controller = controller(
            phase: .scanning(scanned: 1, total: 9),
            warning: true,
            configError: true
        )
        let button = controller.anchorButton

        // The permission triangle wins the glyph; the dimming
        // still says a boot is in flight, which is one channel
        // each rather than two states fighting for one.
        #expect(
            button?.accessibilityLabel()
                == "KiwiDesk (permission required)"
        )
        #expect(button?.appearsDisabled == true)
    }

    @Test("a config error alone leaves the mark undimmed")
    func configErrorDoesNotDim() {
        let controller = controller(
            phase: .ready,
            configError: true
        )
        let button = controller.anchorButton

        #expect(
            button?.accessibilityLabel() == "KiwiDesk (config issues)"
        )
        #expect(button?.appearsDisabled == false)
    }
}
