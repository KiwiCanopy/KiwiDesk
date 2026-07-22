import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// #438: a sticky window is pile-exempt, so a swap that would push a
/// sticky FOCUSED window onto a piled target is refused (with a cue)
/// rather than dead-swapped. `refuseStickyIntoPile` is the gate;
/// pile membership uses the shared cascade detector (#172).
@MainActor
@Suite("Sticky-into-pile refusal (#438)", .serialized)
struct StickyPileRefusalTests {

    private func makeCore() -> KiwiCore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        return KiwiCore(configDirectory: directory)
    }

    private func makeWindow(
        _ id: UInt32,
        isSticky: Bool
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: 100,
            appName: "App",
            isSticky: isSticky
        )
    }

    /// A tiled cell disjoint from the cascade, plus a two-deep
    /// OverlapStack pile — the boundary "last tiled window next to
    /// the pile" geometry.
    private func slots(
        stickyID: UInt32
    ) -> [(id: WindowID, frame: CGRect)] {
        [
            (
                WindowID(stickyID),
                CGRect(x: 0, y: 0, width: 300, height: 300)
            ),
            (
                WindowID(2),
                CGRect(x: 400, y: 0, width: 300, height: 300)
            ),
            (
                WindowID(3),
                CGRect(
                    x: 400,
                    y: OverlapStack.offset,
                    width: 300,
                    height: 300
                )
            ),
        ]
    }

    @Test("Sticky focus onto a piled target is refused")
    func stickyOntoPileRefused() {
        let core = makeCore()
        core.state.windows.upsert(makeWindow(1, isSticky: true))
        // Target 2 sits in a cascade with 3, so it is piled.
        #expect(
            core.refuseStickyIntoPile(
                WindowID(1),
                target: WindowID(2),
                among: slots(stickyID: 1)
            )
        )
    }

    @Test("A non-sticky focus onto a piled target is not refused")
    func nonStickyProceeds() {
        let core = makeCore()
        core.state.windows.upsert(makeWindow(1, isSticky: false))
        #expect(
            !core.refuseStickyIntoPile(
                WindowID(1),
                target: WindowID(2),
                among: slots(stickyID: 1)
            )
        )
    }

    @Test("Sticky focus onto a tiled (unpiled) target proceeds")
    func stickyOntoTiledProceeds() {
        let core = makeCore()
        core.state.windows.upsert(makeWindow(1, isSticky: true))
        // Two disjoint tiled cells, no cascade: target 2 has no
        // pile-mates, so the swap is a normal one.
        let tiled: [(id: WindowID, frame: CGRect)] = [
            (WindowID(1), CGRect(x: 0, y: 0, width: 300, height: 300)),
            (WindowID(2), CGRect(x: 400, y: 0, width: 300, height: 300)),
        ]
        #expect(
            !core.refuseStickyIntoPile(
                WindowID(1),
                target: WindowID(2),
                among: tiled
            )
        )
    }
}
