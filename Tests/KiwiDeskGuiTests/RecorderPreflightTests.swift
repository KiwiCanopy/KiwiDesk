import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

@Suite("Recorder preflight")
@MainActor
struct RecorderPreflightTests {
    @Test("Aliases collide before recorder commit")
    func aliasCollision() throws {
        let own = KeyBinding(combo: "", lua: "own()")
        let holder = KeyBinding(
            combo: "alt+j",
            lua: "holder()",
            label: "Holder"
        )
        var rows = [own, holder]
        let bindings = Binding<[KeyBinding]>(
            get: { rows },
            set: { rows = $0 }
        )

        let rejection = RecorderPreflight.rejection(
            combo: "option+j",
            excluding: { $0.id == own.id },
            bindings: bindings,
            commit: { _ in }
        )

        #expect(try #require(rejection).holder == "Holder")
    }
}
