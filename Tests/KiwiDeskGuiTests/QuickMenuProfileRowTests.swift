import AppKit
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Switch Profile quick-menu row appears only when there is a
/// profile worth switching to — one that isn't the active one and
/// isn't broken. `.serialized` because `LocalizationManager` is a
/// process-wide singleton (titles are matched in English).
@Suite("Quick menu Switch Profile row", .serialized)
@MainActor
struct QuickMenuProfileRowTests {
    private func reset() {
        LocalizationManager.shared.select("en")
    }

    private func controller(
        active: String?,
        all: [String],
        broken: [String] = []
    ) -> StatusItemController {
        let controller = StatusItemController()
        controller.profilesProvider = {
            (active: active, all: all, broken: Set(broken))
        }
        return controller
    }

    private func hasSwitchRow(
        _ controller: StatusItemController
    ) -> Bool {
        let menu = NSMenu()
        controller.menuNeedsUpdate(menu)
        return menu.items.contains { $0.title == "Switch Profile" }
    }

    @Test("hidden with no profiles")
    func noProfiles() {
        reset()
        #expect(!hasSwitchRow(controller(active: nil, all: [])))
    }

    @Test("hidden when the only profile is already active")
    func loneActive() {
        reset()
        #expect(
            !hasSwitchRow(
                controller(active: "Work", all: ["Work"])
            )
        )
    }

    @Test("shown when the only profile isn't active")
    func loneInactive() {
        reset()
        #expect(
            hasSwitchRow(
                controller(active: nil, all: ["Work"])
            )
        )
    }

    @Test("hidden when the only non-active profile is broken")
    func loneBroken() {
        reset()
        #expect(
            !hasSwitchRow(
                controller(
                    active: "Work",
                    all: ["Work", "Bad"],
                    broken: ["Bad"]
                )
            )
        )
    }

    @Test("shown with two switchable profiles")
    func twoProfiles() {
        reset()
        #expect(
            hasSwitchRow(
                controller(
                    active: "Work",
                    all: ["Work", "Play"]
                )
            )
        )
    }
}
