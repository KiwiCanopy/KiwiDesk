import Foundation
import Testing

@testable import KiwiDeskCore

/// The GuiConfig global field list is hand-mirrored in four
/// places — manual `CodingKeys`/decode/encode, the GUI's
/// `globalsChanged` comparison, `guiConfigSeed`, and
/// `applyBehaviorOverrides` / `applyStructuredRules` — past the
/// AGENTS.md §5 two-mirror threshold. Swift reflection cannot
/// inspect those code paths, so the net has two layers: a
/// field-list tripwire (adding a stored property fails here
/// until every mirror site is visited) and a rebuilt-from-JSON
/// round-trip over every sidecar global (a forgotten
/// encode/decode line fails there).
@Suite("GuiConfig mirror parity")
struct GuiConfigParityTests {
    @Test("Field-list tripwire: visit every mirror site")
    func fieldTripwire() {
        // The shared primitive (ReflectionParity.swift), never
        // an inline Mirror copy — a divergent private copy can
        // silently weaken the guard (tests.md).
        let fields = fieldNames(GuiConfig())
        // Adding a field? Decide global vs profile-scoped
        // (#36), then update: CodingKeys + decode + encode
        // (GuiConfig.swift, globals only), `globalsChanged`
        // (SettingsModel+Profiles), `guiConfigSeed`,
        // `applyBehaviorOverrides` / `applyStructuredRules` /
        // `applyProfileScopedState`,
        // the round-trip below — and only then this list.
        //
        // `desktopSpaces` (#1230) deliberately skips ONE of
        // those: `copyGlobals`. It is runtime memory rather than
        // an edited setting, so counting it would light the save
        // pill on every Desktop swipe. It is stamped at the write
        // instead (`GuiConfigStore.liveDesktopSpaces`), which is
        // why no caller has to carry it, and rides `machine.json`
        // (`GuiConfig.machineLocalFields`, `MachineConfig`).
        // `appWide` (#1741) is stamped the same way
        // (`GuiConfigStore.liveAppWide`)
        // and read by `applyStructuredConfig`; so is the shared
        // `look` (#1752, `GuiConfigStore.liveLook`), read by
        // `prepareSharedLook`. `shortcutOffer` (#2324) is the
        // top-ups' bookkeeping: undrafted, written only by them,
        // and merged upward at the write (`GuiConfigStore.save`).
        #expect(
            fields == [
                "format", "settings", "spaces", "spaceModes",
                "appRules", "spacePins", "mainSpaces",
                "fallbackSpace", "floatRules", "ignoreRules",
                "profileBindings", "desktopSpaces", "layers",
                "scrollGesture", "appWide", "look", "spaceHistory",
                "modeCycle", "focusWrap",
                "floatAutomatically", "tileRules",
                "shortcutBase", "shortcutOffer",
            ]
        )
    }

    /// Through the store, which composes `machine.json`'s leaves
    /// in (#2324), so a field dropped from either file reds here.
    @Test("Every sidecar global round-trips non-default")
    func globalsRoundTrip() throws {
        let dir =
            testTemporaryDirectory
            .appendingPathComponent("kiwi-parity-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = GuiConfigStore(
            directory: dir,
            machine: dir.appendingPathComponent("machine")
        )
        var config = GuiConfig()
        config.spaces = [SpaceID("a"), SpaceID("b")]
        config.appRules = ["Mail": SpaceID("a")]
        config.floatRules = ["Calculator"]
        config.ignoreRules = ["io.tailscale.ipn.macos"]
        config.profileBindings = [
            .number(2): DesktopBinding(
                profile: "Studio",
                desktop: 2
            )
        ]
        config.desktopSpaces = [
            .identity(DesktopIdentity(raw: "RT-STAMP")):
                SpaceID("b")
        ]
        var wide = AppWideSettings()
        wide.refusalSound = true
        wide.quitGridTargetDepth = 3
        config.appWide = wide
        var shared = TilingSettings()
        shared.kiwishelf.fillColor = "#123456"
        config.look = LookBody(of: shared)
        // Every field off its default: the base's coding is
        // hand-listed, so a field left default is one unwatched.
        config.scrollGesture = ScrollGestureBase(
            pan: [.command, .shift],
            spaceStep: [],
            naturalTrackpad: false,
            naturalMouse: false,
            longSwipes: true,
            stepDistance: 120
        )
        config.spaceHistory = .allScreens
        config.modeCycle = [.grid, .monocle]
        config.focusWrap = .off
        config.floatAutomatically = false
        config.tileRules = ["com.valvesoftware.steam"]
        config.shortcutBase = .hyper
        config.shortcutOffer = ShortcutOffer(desktop: 4, generation: 2)
        config.layers = [
            KeyLayer(
                name: "default",
                bindings: [
                    KeyBinding(
                        combo: "alt+h",
                        lua: "-- noop",
                        kind: .custom,
                        label: "t"
                    )
                ]
            )
        ]
        try store.saveIncludingBindings(config)
        let back = try #require(store.load())
        expectEqual(back.format, config.format)
        expectEqual(back.spaces, config.spaces)
        expectEqual(back.appRules, config.appRules)
        expectEqual(back.floatRules, config.floatRules)
        expectEqual(back.ignoreRules, config.ignoreRules)
        expectEqual(back.profileBindings, config.profileBindings)
        expectEqual(back.desktopSpaces, config.desktopSpaces)
        expectEqual(back.layers, config.layers)
        expectEqual(back.appWide, config.appWide)
        expectEqual(back.look, config.look)
        expectEqual(back.scrollGesture, config.scrollGesture)
        expectEqual(back.spaceHistory, config.spaceHistory)
        expectEqual(back.modeCycle, config.modeCycle)
        expectEqual(back.focusWrap, config.focusWrap)
        expectEqual(back.floatAutomatically, config.floatAutomatically)
        expectEqual(back.tileRules, config.tileRules)
        expectEqual(back.shortcutBase, config.shortcutBase)
        expectEqual(back.shortcutOffer, config.shortcutOffer)
        // Profile-scoped fields deliberately do NOT ride the
        // sidecar (#36) — they come back default.
        expectEqual(back.settings, TilingSettings())
        #expect(back.spaceModes.isEmpty)
        #expect(back.spacePins.isEmpty)
        #expect(back.mainSpaces.isEmpty)
        #expect(back.fallbackSpace == nil)
    }
}
