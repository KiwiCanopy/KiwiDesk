import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiHub floats over every window, so the focus ring and
/// KiwiVision look past it to the focus beneath (#2373), while an
/// own key window at the normal level still takes both.
@Suite("Floating own panel consumers (#2373)")
@MainActor
struct FloatingOwnPanelConsumerTests {
    private let w1 = WindowID(1)

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-float-own-\(UUID().uuidString)")
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        for id: UInt32 in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: w1)!
        core.state.workspaces.focus(w1, in: space)
        return core
    }

    private func reading(floats: Bool) -> OwnKeyWindowReading {
        OwnKeyWindowReading(
            number: 999_999,
            isDialog: false,
            floatsOverWindows: floats
        )
    }

    @Test("the focused ring stays under a floating own panel")
    func ringStays() {
        let core = makeCore()
        let focused = core.tiler.settings.borderStyle.focusedColor
        core.eventLoop.ownKeyWindow = { reading(floats: true) }
        #expect(core.desiredBorderSpecs().contains { $0.colorHex == focused })
        core.eventLoop.ownKeyWindow = { reading(floats: false) }
        #expect(!core.desiredBorderSpecs().contains { $0.colorHex == focused })
    }

    @Test("KiwiVision targets the focus beneath a floating own panel")
    func visionStays() {
        let core = makeCore()
        core.eventLoop.ownKeyWindow = { reading(floats: true) }
        let beneath = core.visionTarget()
        #expect(beneath.0 == w1.raw)
        #expect(beneath.1 == 1)
        core.eventLoop.ownKeyWindow = { reading(floats: false) }
        #expect(core.visionTarget().0 == 999_999)
    }
}
