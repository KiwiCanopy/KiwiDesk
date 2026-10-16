import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Hover focus's delay (`mouse.hover_focus_delay`, #1869): a
/// Lua-only millisecond knob, never negative, and the dwell the
/// rest's timer actually waits.
@Suite("Hover focus delay (#1869)")
@MainActor
struct HoverFocusDelayTests {
    /// How long a rest the timer fires may take to land: a hang
    /// guard, never a deadline (tests.md, #344).
    private static let hangGuard: Duration = .seconds(30)

    @Test("mouse.set_hover_focus_delay takes milliseconds, 0 or more")
    func verb() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwidesk-delay-\(UUID().uuidString)")
        let core = makeTestCore(configDirectory: directory)
        let mouse = { core.tiler.settings.mouse.hoverFocusDelayMS }
        #expect(mouse() == MouseSettings.defaultHoverFocusDelayMS)
        #expect(
            core.execute("mouse.set_hover_focus_delay", args: [.number(50)])
                .isSuccess
        )
        #expect(mouse() == 50)
        #expect(
            core.execute("mouse.set_hover_focus_delay", args: [.number(0)])
                .isSuccess
        )
        #expect(mouse() == 0)
        #expect(
            !core.execute("mouse.set_hover_focus_delay", args: [.number(-1)])
                .isSuccess
        )
        #expect(
            !core.execute(
                "mouse.set_hover_focus_delay",
                args: [.string("fast")]
            ).isSuccess
        )
        #expect(mouse() == 0)
    }

    @Test("A stored delay decodes, missing is the default, negative is 0")
    func decode() throws {
        func delay(_ json: String) throws -> Int {
            try JSONDecoder().decode(
                TilingSettings.self,
                from: Data(json.utf8)
            ).mouse.hoverFocusDelayMS
        }
        #expect(
            try delay(#"{"mouse":{}}"#)
                == MouseSettings.defaultHoverFocusDelayMS
        )
        #expect(try delay(#"{"mouse":{"hover_focus_delay":80}}"#) == 80)
        #expect(try delay(#"{"mouse":{"hover_focus_delay":-5}}"#) == 0)
    }

    /// That the timer waits `dwell` at all is the gap test's below;
    /// this one holds that a rest the timer fires is delivered.
    @Test("The rest's timer fires a rest")
    func timerWaitsTheDwell() async {
        let rest = PointerRest()
        rest.dwell = .zero
        rest.location = { CGPoint(x: 10, y: 10) }
        var rested = false
        rest.onRest = { _, _ in rested = true }
        rest.moved(to: CGPoint(x: 10, y: 10))
        let clock = ContinuousClock()
        let deadline = clock.now + Self.hangGuard
        while !rested, clock.now < deadline {
            await Task.yield()
        }
        #expect(rested)
        #expect(!rest.isArmed)
    }

    /// The gap half: a dwell an hour long has not rested a second
    /// later, which a timer ignoring `dwell` for the default would.
    @Test("A long dwell has not rested a second later")
    func longDwellWaits() async throws {
        let rest = PointerRest()
        rest.dwell = .seconds(3600)
        rest.location = { CGPoint(x: 10, y: 10) }
        var rested = false
        rest.onRest = { _, _ in rested = true }
        rest.moved(to: CGPoint(x: 10, y: 10))
        try await Task.sleep(for: .seconds(1))
        #expect(!rested)
        #expect(rest.isArmed)
        rest.stop()
    }

    @Test("Settings reach the rest through its one door")
    func applyTakesDelayAndSwitch() {
        let rest = PointerRest()
        var settings = MouseSettings()
        settings.hoverFocus = true
        settings.hoverFocusDelayMS = 75
        rest.apply(settings)
        #expect(rest.dwell == .milliseconds(75))
        #expect(rest.isEnabled)
        settings.hoverFocus = false
        rest.apply(settings)
        #expect(!rest.isEnabled)
    }
}
