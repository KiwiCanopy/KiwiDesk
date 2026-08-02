import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Boot retile batching (#672). The boot scan and the startup
/// sweep surface N windows in one burst; un-batched, every
/// `.windowCreated` ran a full retile + bars + borders + clamp —
/// N passes for one arrangement. `defersEventRetiles` suppresses
/// the per-event structural retile so the raiser's single
/// trailing `retile()` places everything once.
@MainActor
@Suite("Boot retile batching (#672)")
struct StartupRetileBatchTests {
    @Test("a deferred burst places windows in one trailing pass")
    func deferredBurstRetilesOnce() {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-batch-\(UUID().uuidString)"
                )
        )
        // Pin the display (#531); the assertions are counts,
        // and the count must not depend on the host's screen
        // deciding a pile vs a split.
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 900)
        }
        core.tiler.animation.isEnabled = false
        var applied = 0
        core.tiler.animation.apply = { _, _, _ in applied += 1 }

        core.defersEventRetiles = true
        core.handle(
            .windowCreated(
                ManagedWindow(id: WindowID(1), pid: 1, appName: "A")
            )
        )
        core.handle(
            .windowCreated(
                ManagedWindow(id: WindowID(2), pid: 1, appName: "B")
            )
        )
        // The burst itself placed nothing — that is the batch.
        #expect(applied == 0)

        core.defersEventRetiles = false
        core.retile()
        // The one trailing pass placed both windows.
        #expect(applied == 2)
    }
}
