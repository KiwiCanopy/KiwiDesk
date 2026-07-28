import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The `kiwidesk service` login-item awareness lines (#575). The
/// wiring reads live `SMAppService` state, but the rendering is pure
/// over `LoginItemState` and pinned here.
@Suite("Service login-item overlap lines (#575)")
struct LoginItemCLINoteTests {
    @Test("status line reports each login-item state")
    func statusLine() {
        #expect(
            LoginItemCLINote.statusLine(.enabled)
                .hasPrefix("login item: on")
        )
        #expect(
            LoginItemCLINote.statusLine(.notRegistered)
                == "login item: off"
        )
        #expect(
            LoginItemCLINote.statusLine(.requiresApproval)
                .contains("awaiting approval")
        )
        // A bare non-.app binary has no real registration to report
        // — degrade, don't print a misleading state.
        #expect(
            LoginItemCLINote.statusLine(.unavailable(.notBundled))
                == "login item: not applicable from this binary"
        )
    }

    @Test("start note fires only when the login item is also on")
    func startNote() {
        // Reassure only in the genuine overlap; stay silent
        // otherwise so the common `service start` stays clean.
        #expect(LoginItemCLINote.startNote(.enabled) != nil)
        #expect(LoginItemCLINote.startNote(.notRegistered) == nil)
        #expect(LoginItemCLINote.startNote(.requiresApproval) == nil)
        #expect(
            LoginItemCLINote.startNote(.unavailable(.translocated))
                == nil
        )
    }
}
