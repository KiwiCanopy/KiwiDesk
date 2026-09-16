import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A binding remembers the screen its Desktop lives on (#1438)
/// — the second projection beside the Mission Control number,
/// refreshed by the same reconcile and kept while the Desktop
/// is away, so the Desktops card can tell two "Desktop 1" rows
/// apart.
///
/// `.serialized`: the topology overrides are process-global.
@MainActor
@Suite("Desktop binding screen projection (#1438)", .serialized)
struct DesktopBindingScreenTests {
    private let stampA = DesktopIdentity(raw: "SCREEN-A")
    private let stampB = DesktopIdentity(raw: "SCREEN-B")

    /// Two pinned displays (#531): the built-in on `UUID-A`,
    /// an external on `UUID-B`, joined to their UUIDs through
    /// the seam `screenNamesByUUID` reads.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-screen-\(UUID().uuidString)"
                )
        )
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "Built-in",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100)
            )
        )
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(2),
                name: "LG UltraFine",
                frame: CGRect(x: 100, y: 0, width: 100, height: 100)
            )
        )
        return core
    }

    private func pin(_ spaces: [NativeSpace], current: UInt64) {
        NativeSpaces.spacesOverride = spaces
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        NativeSpaces.activeSpaceIDOverride = current
        NativeSpaces.displayUUIDOverride = { id in
            id == DisplayID(1) ? "UUID-A" : "UUID-B"
        }
    }

    private func reset() {
        NativeSpaces.spacesOverride = nil
        NativeSpaces.mainDisplayUUIDOverride = nil
        NativeSpaces.activeSpaceIDOverride = nil
        NativeSpaces.displayUUIDOverride = nil
    }

    private func desk(
        _ id: UInt64,
        on uuid: String,
        _ identity: DesktopIdentity?,
        current: UInt64
    ) -> NativeSpace {
        NativeSpace(
            id: id,
            displayUUID: uuid,
            isCurrent: id == current,
            identity: identity
        )
    }

    /// Desktop 1 on the built-in, Desktop 2 on the external.
    private func twoScreens(current: UInt64 = 10) -> [NativeSpace] {
        [
            desk(10, on: "UUID-A", stampA, current: current),
            desk(20, on: "UUID-B", stampB, current: current),
        ]
    }

    @Test("the bind verb records the screen the Desktop is on")
    func bindVerbRecordsTheScreen() {
        defer { reset() }
        pin(twoScreens(), current: 10)
        let core = makeCore()
        core.execute(
            "bind_profile_to_desktop",
            args: [.number(2), .string("Work")]
        )
        #expect(
            core.desktopBindings[.identity(stampB)]?.screen
                == "LG UltraFine"
        )
    }

    /// The reconcile re-projects the screen the way it
    /// re-projects the number — a Desktop that moved screens
    /// (or a record written before the field existed) is named
    /// by the reading in hand, in memory and in the sidecar.
    @Test("the reconcile refreshes a stale or missing screen")
    func reconcileRefreshesTheScreen() throws {
        defer { reset() }
        pin(twoScreens(), current: 10)
        let core = makeCore()
        var stored = GuiConfig()
        stored.profileBindings = [
            .identity(stampA): DesktopBinding(
                profile: "Work",
                desktop: 1,
                screen: "Old"
            ),
            .identity(stampB): DesktopBinding(
                profile: "Other",
                desktop: 2
            ),
        ]
        try core.guiConfigStore.save(stored)
        core.desktopBindings = stored.profileBindings

        _ = core.stampedDesktopSnapshot()

        #expect(
            core.desktopBindings[.identity(stampA)]?.screen
                == "Built-in"
        )
        #expect(
            core.desktopBindings[.identity(stampB)]?.screen
                == "LG UltraFine"
        )
        let after = try #require(core.guiConfigStore.load())
        #expect(
            after.profileBindings[.identity(stampB)]?.screen
                == "LG UltraFine"
        )
    }

    /// A display the UUID symbol cannot name leaves the
    /// remembered screen alone — a nil never overwrites a name,
    /// or every bridgeless reading would blank the card.
    @Test("an unnamed display keeps the remembered screen")
    func unnamedDisplayKeepsTheScreen() {
        defer { reset() }
        pin(twoScreens(), current: 10)
        NativeSpaces.displayUUIDOverride = { _ in nil }
        let core = makeCore()
        core.desktopBindings = [
            .identity(stampB): DesktopBinding(
                profile: "Work",
                desktop: 2,
                screen: "LG UltraFine"
            )
        ]
        _ = core.stampedDesktopSnapshot()
        #expect(
            core.desktopBindings[.identity(stampB)]?.screen
                == "LG UltraFine"
        )
    }

    /// A dormant record keeps the screen it was last seen on —
    /// that name is what the row says while the screen is
    /// unplugged, so nothing may clear it on absence.
    @Test("a dormant record keeps its screen")
    func dormantRecordKeepsItsScreen() {
        defer { reset() }
        pin([desk(10, on: "UUID-A", stampA, current: 10)], current: 10)
        let core = makeCore()
        core.desktopBindings = [
            .identity(stampB): DesktopBinding(
                profile: "Work",
                desktop: 2,
                screen: "LG UltraFine"
            )
        ]
        _ = core.stampedDesktopSnapshot()
        #expect(
            core.desktopBindings[.identity(stampB)]?.screen
                == "LG UltraFine"
        )
    }

    /// The live row's read: every present user Desktop, under
    /// both of its keys, named by the screen it lives on.
    @Test("desktopScreens names every present Desktop by key")
    func desktopScreensNamesEveryPresentDesktop() {
        defer { reset() }
        pin(twoScreens(), current: 10)
        let core = makeCore()
        let screens = core.desktopScreens(
            in: NativeSpaces.desktopSnapshot()
        )
        #expect(screens[.identity(stampA)] == "Built-in")
        #expect(screens[.number(1)] == "Built-in")
        #expect(screens[.identity(stampB)] == "LG UltraFine")
        #expect(screens[.number(2)] == "LG UltraFine")
    }

    /// Additive on the wire: a record written before #1438
    /// decodes with no screen, and one that has none encodes
    /// no key — so a previous build's decoder never meets a
    /// value it does not know, and no format bump is owed.
    @Test("the screen is encoded only where set")
    func screenIsEncodedOnlyWhereSet() throws {
        var config = GuiConfig()
        config.profileBindings = [
            .number(1): DesktopBinding(profile: "Work", desktop: 1)
        ]
        let bare = try JSONEncoder().encode(config)
        let bareText = try #require(String(data: bare, encoding: .utf8))
        #expect(!bareText.contains("\"screen\""))
        let decoded = try JSONDecoder().decode(GuiConfig.self, from: bare)
        #expect(decoded.profileBindings[.number(1)]?.screen == nil)

        config.profileBindings[.number(1)]?.screen = "Built-in"
        let named = try JSONEncoder().encode(config)
        let roundTrip = try JSONDecoder().decode(
            GuiConfig.self,
            from: named
        )
        #expect(
            roundTrip.profileBindings[.number(1)]?.screen
                == "Built-in"
        )
    }
}
