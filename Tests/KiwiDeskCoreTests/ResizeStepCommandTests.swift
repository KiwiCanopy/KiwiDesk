import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
        configDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-resize-\(UUID().uuidString)"
            )
    )
}

/// `set_resize_step` stores a whole point count in a sane range,
/// so the catalog's integer authoring can always represent it and
/// no argument can trap the `Int` funnel (#58 review).
@MainActor
struct ResizeStepCommandTests {
    @Test("Stores a whole step as given")
    func storesStep() {
        let core = makeCore()
        _ = core.execute("set_resize_step", args: [.number(75)])
        #expect(core.tiler.settings.resizeStep == 75)
    }

    @Test("Rounds a fractional step to whole points")
    func roundsFractional() {
        let core = makeCore()
        _ = core.execute(
            "set_resize_step",
            args: [.number(50.5)]
        )
        #expect(core.tiler.settings.resizeStep == 51)
    }

    @Test("Clamps a non-positive step up to 1")
    func clampsNonPositive() {
        let core = makeCore()
        _ = core.execute("set_resize_step", args: [.number(0)])
        #expect(core.tiler.settings.resizeStep == 1)
        _ = core.execute("set_resize_step", args: [.number(-9)])
        #expect(core.tiler.settings.resizeStep == 1)
    }

    @Test("Caps an enormous step instead of trapping the Int")
    func capsHugeStep() {
        let core = makeCore()
        _ = core.execute(
            "set_resize_step",
            args: [.number(1e300)]
        )
        #expect(core.tiler.settings.resizeStep == 10_000)
    }

    @Test("Rejects a non-finite step, keeping the prior value")
    func rejectsNonFinite() {
        let core = makeCore()
        _ = core.execute("set_resize_step", args: [.number(75)])
        _ = core.execute(
            "set_resize_step",
            args: [.number(.infinity)]
        )
        #expect(core.tiler.settings.resizeStep == 75)
    }
}
