import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    KiwiCore(
        configDirectory: FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "kiwi-own-\(UUID().uuidString)"
            )
    )
}

/// A core whose config is GUI-managed (a `gui.json` sidecar
/// exists).
@MainActor
private func makeGuiManagedCore() -> KiwiCore {
    let core = makeCore()
    try? core.guiConfigStore.save(GuiConfig())
    return core
}

@MainActor
private func connect(
    _ core: KiwiCore,
    _ displays: [Display]
) {
    for display in displays {
        core.state.workspaces.upsertDisplay(display)
    }
}

private func display(
    _ id: UInt32,
    _ name: String,
    x: CGFloat = 0
) -> Display {
    Display(
        id: DisplayID(id),
        name: name,
        frame: CGRect(x: x, y: 0, width: 100, height: 100)
    )
}

/// Verifies the token-scoped GUI-ownership semantics (#14):
/// harmless custom Lua coexists with the visual editor
/// (isGuiManaged stays true); only code touching the managed
/// vocabulary demotes ownership.
@Suite("GUI ownership / coexistence", .serialized)
@MainActor
struct GuiOwnershipTests {
    @Test(
        "managed-vocab Lua beside gui.json keeps tiling Lua-owned"
    )
    func managedVocabCodeKeepsLuaOwned() throws {
        let core = makeGuiManagedCore()
        connect(core, [display(1, "A")])
        core.state.workspaces.ensureSpace(SpaceID(1))
        // A binding outside the block touches KiwiDesk.bind(,
        // which the GUI also writes inside the block — the
        // visual editor yields to the raw Lua fallback.
        let lua =
            "KiwiDesk.bind(\"alt+h\", function() end)"
        try lua.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        #expect(core.configHasForeignCode)
        #expect(!core.isGuiManaged)
        core.tiler.settings.gapsGlobal = .uniform(30)

        core.handleMonitorChange()
        // The Standard must NOT be applied — tiling stays
        // Lua-owned, no dirty state from the monitor change.
        #expect(core.profiles.currentStandard == nil)
        #expect(!core.profiles.isDirty)
        #expect(
            core.tiler.settings.gapsGlobal == .uniform(30)
        )
    }

    @Test(
        "tiling Lua beside gui.json yields to Standard"
    )
    func tilingLuaYieldsToStandardOnMonitorChange() throws {
        let core = makeGuiManagedCore()
        connect(core, [display(1, "A")])
        core.state.workspaces.ensureSpace(SpaceID(1))
        // set_gap_global is NOT managed vocabulary: no raw
        // editor forced, isGuiManaged stays true (#14).
        // But once gui.json exists the Standard owns tiling
        // on a monitor change and overrides this Lua call.
        // This is INTENDED: harmless tiling Lua flips back
        // to GUI ownership; set_gap_global is not in the
        // managed block (tiling lives in profiles, #36).
        let lua = "KiwiDesk.set_gap_global(30)"
        try lua.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        #expect(!core.configHasForeignCode)
        #expect(core.configHasCustomCode)
        #expect(core.isGuiManaged)
        // Simulate the Lua tiling call having been applied.
        core.tiler.settings.gapsGlobal = .uniform(30)

        core.handleMonitorChange()
        // The composed Standard is applied (Developer: 8 pt
        // uniform gaps), overriding the hand-set 30 pt gap.
        #expect(core.profiles.currentStandard != nil)
        #expect(
            core.tiler.settings.gapsGlobal == .uniform(8)
        )
    }

    @Test(
        "harmless custom Lua beside gui.json stays GUI-managed"
    )
    func harmlessCustomLuaIsGuiManaged() throws {
        let core = makeGuiManagedCore()
        connect(core, [display(1, "A")])
        // Code that does NOT touch managed vocabulary — e.g.
        // a debug call or a sketchybar hook. The visual editor
        // remains active; the GUI still owns tiling (#14).
        try "KiwiDesk.debug_log(\"hello\")".write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        #expect(!core.configHasForeignCode)
        #expect(core.configHasCustomCode)
        #expect(core.isGuiManaged)
        // The Standard is applied on monitor change because
        // GUI ownership is intact.
        core.handleMonitorChange()
        #expect(core.profiles.currentStandard != nil)
    }
}
