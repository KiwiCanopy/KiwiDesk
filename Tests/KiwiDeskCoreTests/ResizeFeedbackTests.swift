import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-resize-cue-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

/// The refusal cue's audible half (#184, widened #1255). The
/// beep itself is an AppKit side effect; what the tests pin is
/// the seam around it: the toggle's storage and validation, the
/// CLI contract staying an error response, and the
/// hotkey-origin flag defaulting off outside a fire (so
/// command-path callers can never cue).
@Suite("Unsupported-resize feedback (#184)", .serialized)
@MainActor
struct ResizeFeedbackTests {
    @Test("set_refusal_sound toggles and validates")
    func toggle() {
        let core = makeCore()
        // OFF by default since #1255: the pill is the primary
        // cue and the sound is switched on, so widening it to
        // every refusal makes no upgrade noisier.
        #expect(!core.tiler.settings.refusalSound)
        // Both directions, which the old cut never had — it
        // only ever drove the flag toward its non-default.
        #expect(
            core.execute(
                "set_refusal_sound",
                args: [.bool(true)]
            ).isSuccess
        )
        #expect(core.tiler.settings.refusalSound)
        #expect(
            core.execute(
                "set_refusal_sound",
                args: [.bool(false)]
            ).isSuccess
        )
        #expect(!core.tiler.settings.refusalSound)
        #expect(
            !core.execute(
                "set_refusal_sound",
                args: [.string("loud")]
            ).isSuccess
        )
        #expect(!core.tiler.settings.refusalSound)
    }

    @Test("CLI resize failure stays a plain error response")
    func cliContractUnchanged() {
        let core = makeCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(1), pid: 1, appName: "A")
            )
        )
        let space = core.state.workspaces.space(
            of: WindowID(1)
        )!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("monocle")]
        )
        let response = core.execute(
            "resize",
            args: [.string("x"), .number(50)]
        )
        #expect(!response.isSuccess)
        #expect(response.error == "resize not supported in monocle")
    }

    @Test("The hotkey-origin flag is off outside a fire")
    func notFiringByDefault() {
        let core = makeCore()
        #expect(!core.keys.isFiring)
    }
}
