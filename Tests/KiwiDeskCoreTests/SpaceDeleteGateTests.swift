import Testing

@testable import KiwiDeskCore

/// Pins the destructive-delete confirm gate (#205):
/// `GuiConfig.carriesOverrides` must trip for every kind of
/// per-space work the delete cascade would discard (pin, Main
/// role, fallback, a settings override), and must NOT trip for a
/// space that only holds a name and a layout mode — otherwise
/// either every delete nags, or a customized delete silently
/// drops work. The settings half is probed by mutate-and-compare
/// against `TilingSettings.removeSpace`, so this also guards that
/// wiring end to end.
@Suite("Space delete confirm gate (#205)")
struct SpaceDeleteGateTests {
    private let space = SpaceID("1")

    private func config() -> GuiConfig {
        var c = GuiConfig()
        c.spaces = [space]
        return c
    }

    @Test("Bare space (name only) needs no confirm")
    func bareSpace() {
        #expect(config().carriesOverrides(space) == false)
    }

    @Test("A bare layout mode alone does not trip the gate")
    func modeOnly() {
        var c = config()
        c.spaceModes[space] = .scrolling
        #expect(c.carriesOverrides(space) == false)
    }

    @Test("A monitor pin trips the gate")
    func pin() {
        var c = config()
        c.spacePins[space] = "MONITOR-A"
        #expect(c.carriesOverrides(space))
    }

    @Test("The Main role trips the gate")
    func mainRole() {
        var c = config()
        c.mainSpaces.insert(space)
        #expect(c.carriesOverrides(space))
    }

    @Test("The Fallback role trips the gate")
    func fallback() {
        var c = config()
        c.fallbackSpace = space
        #expect(c.carriesOverrides(space))
    }

    @Test("A per-space settings override trips the gate")
    func settingsOverride() {
        var c = config()
        c.settings.spaceIcons[space] = "star"
        #expect(c.carriesOverrides(space))
    }

    @Test("The gate is scoped to the space asked about")
    func scopedToSpace() {
        var c = config()
        c.spaces = [space, SpaceID("2")]
        c.spacePins[space] = "MONITOR-A"
        #expect(c.carriesOverrides(SpaceID("2")) == false)
    }
}
