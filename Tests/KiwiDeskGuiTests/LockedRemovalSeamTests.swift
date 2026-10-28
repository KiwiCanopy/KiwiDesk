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
        // The whole closure body, so an added condition reds too.
        let rest = source[wire.upperBound...]
        let body = rest.prefix { $0 != "}" }
        #expect(
            body.trimmingCharacters(in: .whitespacesAndNewlines)
                == "SessionPresence.live().screenLocked == true"
        )
    }

    @Test("both makeTestCore twins pin the read unlocked")
    func twinsPinTheRead() throws {
        // The twins are held identical to each other, so a pin
        // deleted from both reds nowhere else.
        let root = SourceScan.repoRoot(from: #filePath)
        for target in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let file = root.appendingPathComponent(
                "Tests/\(target)/TestCore.swift"
            )
            let source = try SourceScan.strippedSource(at: file)
            #expect(
                source.contains(
                    "core.eventLoop.lockedRemovals.isLocked = { false }"
                ),
                "\(target) does not pin the lock read"
            )
        }
    }
}
