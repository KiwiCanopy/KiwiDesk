import Foundation
import Testing

@testable import KiwiDeskCore

/// The two `DesktopMemory` reads both `makeTestCore` twins pin
/// (#3442) still answer a suite's stated override: the display UUID
/// over its per-process memo, the active Space over its pinned true.
/// That the active pin answers true with no topology cannot red on a
/// host sitting on a user Desktop, which answers true live;
/// `SpaceReadSeamGuardTests` holds that pin's text instead.
@Suite("Test-core display-UUID and active-Space pins")
@MainActor
struct TestCoreSpaceReadPinTests {
    @Test("a stated active-Space override answers through the pin")
    func activeSpaceDefaultsToUser() {
        let core = makeTestCore()
        #expect(core.desktopMemory.readActiveSpaceIsUser())
        NativeSpaces.activeSpaceIsUserOverride = false
        defer { NativeSpaces.activeSpaceIsUserOverride = nil }
        #expect(!core.desktopMemory.readActiveSpaceIsUser())
    }

    @Test("a stated display-UUID override answers through the pin")
    func displayUUIDTakesTheOverride() {
        let core = makeTestCore()
        // A display no host holds, read once first so the memo holds
        // it: the override must still beat the memoized answer.
        let display = DisplayID(903_442)
        #expect(core.desktopMemory.readDisplayUUID(display) == nil)
        NativeSpaces.displayUUIDOverride = { _ in "UUID-PIN" }
        defer { NativeSpaces.displayUUIDOverride = nil }
        #expect(core.desktopMemory.readDisplayUUID(display) == "UUID-PIN")
    }
}
