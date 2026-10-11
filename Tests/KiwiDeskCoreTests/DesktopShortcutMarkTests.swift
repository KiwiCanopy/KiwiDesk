import Foundation
import Testing

@testable import KiwiDeskCore

/// The Desktop tier's mark only climbs: a Desktop at or below it
/// was offered before, so a row deleted there stays deleted even
/// after that Desktop goes away and comes back — and a profile's
/// own Go to Desktop row counts as the action bound.
@Suite("The Desktop shortcut mark only climbs", .serialized)
@MainActor
struct DesktopShortcutMarkTests {
    private final class Mark { var value = 0 }

    private func lua(_ number: Int) -> String {
        "KiwiDesk.focus_desktop(\(number))"
    }

    private func makeCore(mark: Mark) throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-desktop-mark-\(UUID().uuidString)"
                )
        )
        try core.guiConfigStore.save(GuiConfig())
        core.desktopMemory.readShortcutMark = { mark.value }
        core.desktopMemory.writeShortcutMark = { mark.value = $0 }
        return core
    }

    private func desktopRows(_ core: KiwiCore) -> [String] {
        (core.persistedGuiConfig()?.layers.first { $0.isDefault }?
            .bindings ?? [])
            .map(\.lua).filter { $0.hasPrefix("KiwiDesk.focus_desktop(") }
    }

    @Test("A Desktop that leaves and comes back stays deleted")
    func fewerDesktopsNeverLowerTheMark() throws {
        let mark = Mark()
        let core = try makeCore(mark: mark)
        core.topUpDesktopShortcuts(desktops: [1, 2, 3, 4])
        var config = try #require(core.persistedGuiConfig())
        let index = try #require(config.layers.firstIndex { $0.isDefault })
        config.layers[index].bindings.removeAll { $0.lua == lua(4) }
        try core.guiConfigStore.save(config)

        core.topUpDesktopShortcuts(desktops: [1, 2, 3])
        #expect(mark.value == 4)
        core.topUpDesktopShortcuts(desktops: [1, 2, 3, 4])
        #expect(!desktopRows(core).contains(lua(4)))
    }

    @Test("A profile's own Desktop row counts as bound")
    func profileRowCountsAsBound() throws {
        let mark = Mark()
        let core = try makeCore(mark: mark)
        var profile = Profile(
            name: "Work",
            monitorSets: [MonitorSet(monitors: [])],
            spaces: [SpaceID("1")],
            spaceModes: [:],
            settings: TilingSettings()
        )
        profile.layers = KeyLayerOverride(layers: [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "alt+2",
                        lua: lua(2),
                        kind: .navigation
                    )
                ]
            )
        ])
        try core.profiles.write(profile)
        core.topUpDesktopShortcuts(desktops: [1, 2])
        #expect(desktopRows(core) == [lua(1)])
    }
}
