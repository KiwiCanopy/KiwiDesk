import Foundation
import Testing

@testable import KiwiDeskCore

/// An app verb passed a running app's NAME is refused naming that
/// app's bundle id (#2222); the verbs still resolve nothing by
/// name, so the refusal stands.
@Suite("App verbs name the bundle id (#2222)")
@MainActor
struct AppVerbHintTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore()
        core.openOrFocus.bundleIDNamed = {
            $0.lowercased() == "safari" ? "com.apple.Safari" : nil
        }
        return core
    }

    @Test(
        "each app verb's refusal names the bundle id",
        arguments: [
            "focus_or_spawn", "spawn_new", "gather", "move_here",
        ]
    )
    func refusalNamesTheID(_ verb: String) {
        let core = makeCore()
        let response = core.execute(verb, args: [.string("Safari")])
        #expect(!response.isSuccess)
        #expect(
            response.error?.hasSuffix(
                " — did you mean 'com.apple.Safari'?"
            ) == true,
            "\(response.error ?? "nil")"
        )
    }

    @Test("an unknown name and a bundle id take no hint")
    func noHintWithoutAMatch() {
        let core = makeCore()
        let unknown = core.execute(
            "focus_or_spawn",
            args: [.string("Nonesuch")]
        )
        #expect(unknown.error == "app not found: nonesuch")
        core.openOrFocus.bundleIDNamed = { _ in "com.apple.Safari" }
        let id = core.execute(
            "spawn_new",
            args: [.string("com.apple.Safari")]
        )
        #expect(id.error == "app not found: com.apple.safari")
    }

    @Test("a success is never rewritten")
    func successIsUntouched() {
        let core = makeCore()
        core.openOrFocus.openApp = { _, _ in true }
        #expect(
            core.execute("spawn_new", args: [.string("Safari")])
                .isSuccess
        )
    }
}
