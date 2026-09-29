import Foundation
import Testing

@testable import KiwiDeskCore

/// The GuiConfig global field list is hand-mirrored in four
/// places — manual `CodingKeys`/decode/encode, the GUI's
/// `globalsChanged` comparison, `guiConfigSeed`, and
/// `applyStructuredRules` — past the AGENTS.md §5 two-mirror
/// threshold. Swift reflection cannot inspect those code paths,
/// so the net has two layers: a field-list tripwire (adding a
/// stored property fails here until every mirror site is
/// visited) and a rebuilt-from-JSON round-trip over every
/// sidecar global (a forgotten encode/decode line fails there).
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
        // `applyStructuredRules` / `applyProfileScopedState`,
        // the round-trip below — and only then this list.
        //
        // `desktopSpaces` (#1230) deliberately skips ONE of
        // those: `copyGlobals`. It is runtime memory rather than
        // an edited setting, so counting it would light the save
        // pill on every Desktop swipe. It is stamped at the write
        // instead (`GuiConfigStore.liveDesktopSpaces`), which is
        // why no caller has to carry it. `appWide` (#1741) is
        // stamped the same way (`GuiConfigStore.liveAppWide`)
        // and read by `applyStructuredConfig`; so is the shared
        // `look` (#1752, `GuiConfigStore.liveLook`), read by
        // `prepareSharedLook`.
        #expect(
            fields == [
                "format", "settings", "spaces", "spaceModes",
                "appRules", "spacePins", "mainSpaces",
                "fallbackSpace", "floatRules", "ignoreRules",
                "profileBindings", "desktopSpaces", "layers",
                "scrollGesture", "appWide", "look",
            ]
        )
    }

    @Test("Every sidecar global round-trips non-default")
    func globalsRoundTrip() throws {
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
        let back = try JSONDecoder().decode(
            GuiConfig.self,
            from: JSONEncoder().encode(config)
        )
        #expect(back.format == config.format)
        #expect(back.spaces == config.spaces)
        #expect(back.appRules == config.appRules)
        #expect(back.floatRules == config.floatRules)
        #expect(back.ignoreRules == config.ignoreRules)
        #expect(back.profileBindings == config.profileBindings)
        #expect(back.desktopSpaces == config.desktopSpaces)
        #expect(back.layers == config.layers)
        #expect(back.appWide == config.appWide)
        #expect(back.look == config.look)
        #expect(back.scrollGesture == config.scrollGesture)
        // Profile-scoped fields deliberately do NOT ride the
        // sidecar (#36) — they come back default.
        #expect(back.settings == TilingSettings())
        #expect(back.spaceModes.isEmpty)
        #expect(back.spacePins.isEmpty)
        #expect(back.mainSpaces.isEmpty)
        #expect(back.fallbackSpace == nil)
    }
}
