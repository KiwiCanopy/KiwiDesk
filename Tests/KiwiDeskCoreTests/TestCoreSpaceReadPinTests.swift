import Foundation
import Testing

@testable import KiwiDeskCore

/// The two `DesktopMemory` reads both `makeTestCore` twins pin
/// (#3442) answer the bridge-absent host, and still answer a
/// suite's stated override rather than the memo.
@Suite("Test-core display-UUID and active-Space pins")
@MainActor
struct TestCoreSpaceReadPinTests {
    @Test("the active Space reads as a user Desktop unless stated")
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
