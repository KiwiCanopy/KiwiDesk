import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Core top-ups read the STORED base (#2460): the pure
/// producers take it as an argument, so only a run through the core
/// sees a top-up that hands them the seed's base instead.
@Suite("Top-ups read the stored shortcut base (#2460)", .serialized)
@MainActor
struct ShortcutBaseTopUpWiringTests {
    private func core(
        rows: [KeyBinding] = [],
        base: ShortcutBase = .hyper
    ) throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-base-topup-\(UUID().uuidString)"
                )
        )
        var config = GuiConfig()
        config.shortcutBase = base
        let index = try #require(config.layers.firstIndex { $0.isDefault })
        config.layers[index].bindings = rows
        try core.guiConfigStore.save(config)
        core.desktopMemory.readLegacyShortcutOffer = { nil }
        return core
    }

    private func rows(_ core: KiwiCore) -> [KeyBinding] {
        core.persistedGuiConfig()?.layers.first { $0.isDefault }?
            .bindings ?? []
    }

    @Test("a new Space's digits land on the stored base")
    func digitTopUpReadsTheStore() throws {
        let core = try core()
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "A",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100)
            )
        )
        core.state.workspaces.ensureSpace(SpaceID("3"))
        core.topUpDigitShortcuts()
        let combo = rows(core).first {
            $0.lua == "KiwiDesk.focus_space(\"3\")"
        }?.combo
        #expect(combo == "hyper+3")
    }

    @Test("a later generation's rows land on the stored base")
    func generationTopUpReadsTheStore() throws {
        let core = try core()
        core.topUpGenerationShortcuts()
        let reset = DefaultKeybindings.resetSizesRow()
        let combo = rows(core).first { $0.lua == reset.lua }?.combo
        #expect(combo == "hyper+r")
    }

    @Test("a new Desktop's row lands on the stored base")
    func desktopTopUpReadsTheStore() throws {
        let core = try core()
        core.topUpDesktopShortcuts(desktops: [1])
        let combo = rows(core).first {
            $0.lua == "KiwiDesk.focus_desktop(1)"
        }?.combo
        #expect(combo == "hyper+option+1")
    }
}
