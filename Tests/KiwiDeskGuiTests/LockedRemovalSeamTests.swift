import Foundation
import Testing

/// The removal pause's lock read is WIRED (#2538). The seam
/// defaults to "unlocked" so every harness stays inert, and both
/// `makeTestCore` twins pin it after bootstrap, so no behaviour
/// suite can see the production wiring: delete it and every
/// suite stays green while a lock closes the desk again.
@Suite("Locked removal seam (#2538)")
struct LockedRemovalSeamTests {
    @Test("bootstrap wires the lock read to the session flag")
    func lockReadIsWired() throws {
        let source = try SourceScan.functionBody(
            of: "bootstrapCoreServices",
            in: "KiwiCore+Bootstrap.swift",
            under: "App"
        )
        guard
            let wire = source.range(
                of: "eventLoop.lockedRemovals.isLocked = {"
            )
        else {
            Issue.record("the lock read is not wired")
            return
        }
        let body = source[wire.upperBound...].prefix(80)
        #expect(
            body.contains("SessionPresence.live().screenLocked == true")
        )
    }
}
