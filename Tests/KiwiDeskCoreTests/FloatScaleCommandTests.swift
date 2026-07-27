import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-float-scale-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

/// `set_float_scale_on_display_change` (#502): the proportional
/// size scaling knob (ON by default). Pins its dispatch —
/// storage, bool validation, and the on default. The scaling math
/// itself lives in `FloatReanchorTests`. Flat verb beside
/// `float_nudge`, dispatched with no retile (the flag is read only
/// at a future re-anchor).
@Suite("set_float_scale_on_display_change (#502)", .serialized)
@MainActor
struct FloatScaleCommandTests {
    @Test("The command toggles and validates")
    func toggle() {
        let core = makeCore()
        // On by default (#502 superseded the keep-the-size default).
        #expect(core.tiler.settings.floatScaleOnDisplayChange)
        #expect(
            core.execute(
                "set_float_scale_on_display_change",
                args: [.bool(false)]
            ).isSuccess
        )
        #expect(!core.tiler.settings.floatScaleOnDisplayChange)
        // A non-bool arg is rejected and leaves the flag intact.
        #expect(
            !core.execute(
                "set_float_scale_on_display_change",
                args: [.string("yes")]
            ).isSuccess
        )
        #expect(!core.tiler.settings.floatScaleOnDisplayChange)
    }
}
