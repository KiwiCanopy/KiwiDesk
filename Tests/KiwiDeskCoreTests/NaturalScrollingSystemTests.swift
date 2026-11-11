import Foundation
import Testing

@testable import KiwiDeskCore

/// Natural scrolling's third value (#3200 ruling, 2026-11-11):
/// `"system"` follows macOS's own choice live, a boolean pins it,
/// and the wire takes exactly those three.
@Suite("Natural scrolling follows the system", .serialized)
@MainActor
struct NaturalScrollingSystemTests {
    private func decode(_ json: String) throws -> NaturalScrolling {
        try JSONDecoder().decode(
            NaturalScrolling.self,
            from: Data(json.utf8)
        )
    }

    @Test("the wire takes \"system\", true and false, and nothing else")
    func wire() throws {
        #expect(try decode("\"system\"") == .system)
        #expect(try decode("true") == .on)
        #expect(try decode("false") == .off)
        #expect(throws: (any Error).self) { try decode("\"auto\"") }
        #expect(throws: (any Error).self) { try decode("1") }
        for value in NaturalScrolling.allCases {
            let data = try JSONEncoder().encode(value)
            #expect(
                try JSONDecoder().decode(NaturalScrolling.self, from: data)
                    == value
            )
        }
    }

    @Test("a fresh base follows the system")
    func freshIsSystem() {
        #expect(ScrollGestureBase.defaults.naturalTrackpad == .system)
        #expect(ScrollGestureBase.defaults.naturalMouse == .system)
    }

    /// The host is read at the first start and again on its change
    /// notice, each move re-running the bootstrap-wired resolve; a
    /// pinned input ignores it.
    @Test("a system input follows macOS's change; a pinned one does not")
    func followsTheHost() {
        let core = makeTestCore()
        var host: Bool? = false
        var notice: (@MainActor () -> Void)?
        core.mouse.scroll.host = HostNaturalScrolling(
            read: { host },
            watch: { notice = $0 }
        )
        var base = ScrollGestureBase.defaults
        base.naturalMouse = .on
        core.applyScrollGestures(base: base, profile: nil)
        core.mouse.scroll.followHost()
        #expect(!core.mouse.scroll.settings.naturalTrackpad)
        #expect(core.mouse.scroll.settings.naturalMouse)
        host = true
        notice?()
        #expect(core.mouse.scroll.settings.naturalTrackpad)
        #expect(core.mouse.scroll.settings.naturalMouse)
    }

    @Test("an unset key reads as on")
    func unsetIsOn() {
        let core = makeTestCore()
        core.mouse.scroll.followHost()
        core.applyScrollGestures(profile: nil)
        #expect(core.mouse.scroll.settings.naturalTrackpad)
    }
}
