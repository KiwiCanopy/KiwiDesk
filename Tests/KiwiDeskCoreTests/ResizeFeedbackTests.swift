import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-resize-cue-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: directory)
}

/// The unsupported-resize cue (#184). The beep itself is an
/// AppKit side effect; what the tests pin is the seam around
/// it: the toggle's storage and validation, the CLI contract
/// staying an error response, and the hotkey-origin flag
/// defaulting off outside a fire (so command-path callers can
/// never cue).
@Suite("Unsupported-resize feedback (#184)", .serialized)
@MainActor
struct ResizeFeedbackTests {
    @Test("set_resize_feedback toggles and validates")
    func toggle() {
        let core = makeCore()
        #expect(core.tiler.settings.resizeFeedback)
        #expect(
            core.execute(
                "set_resize_feedback",
                args: [.bool(false)]
            ).isSuccess
        )
        #expect(!core.tiler.settings.resizeFeedback)
        #expect(
            !core.execute(
                "set_resize_feedback",
                args: [.string("loud")]
            ).isSuccess
        )
        #expect(!core.tiler.settings.resizeFeedback)
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
