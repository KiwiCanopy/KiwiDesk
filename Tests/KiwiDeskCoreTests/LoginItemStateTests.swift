import ServiceManagement
import Testing

@testable import KiwiDeskCore

/// The pure OS-status → `LoginItemState` mapping (#342). The real
/// `register()`/`unregister()` calls touch `SMAppService` and can't
/// run headless, but the mapping and the `isOn` derivation — the
/// logic the read-through toggle depends on — are pure and pinned
/// here.
@Suite("Login-item state mapping (#342)")
struct LoginItemStateTests {
    @Test("each SMAppService status maps to its state")
    func statusMapping() {
        #expect(
            LoginItemManager.state(from: .enabled) == .enabled
        )
        #expect(
            LoginItemManager.state(from: .notRegistered)
                == .notRegistered
        )
        #expect(
            LoginItemManager.state(from: .requiresApproval)
                == .requiresApproval
        )
        // `.notFound` is the pre-registration state for `mainApp`,
        // so a registerable app offers to turn it on rather than
        // greying out. (The terminal `.notFound` — translocated /
        // bare binary — is gated to `.unavailable` in `current` by
        // the location check, which reads `Bundle.main` and so is
        // not exercised by this pure mapping.)
        #expect(
            LoginItemManager.state(from: .notFound) == .notRegistered
        )
    }

    @Test("unavailable-reason gate discriminates the three cases")
    func unavailableReason() {
        // A normal /Applications bundle is registerable (nil), so
        // its `.notFound` reads as "turn it on", not greyed.
        let app = URL(fileURLWithPath: "/Applications/KiwiDesk.app")
        // A Gatekeeper-translocated copy is terminal: registering
        // would point the item at an ephemeral randomized path.
        let translocated = URL(
            fileURLWithPath:
                "/private/var/folders/x/T/AppTranslocation/"
                + "ABC/d/KiwiDesk.app"
        )
        // A bare non-bundled binary: bundle URL is the containing
        // dir, not an `.app`.
        let bareBinary = URL(
            fileURLWithPath: "/Users/me/.build/release"
        )
        #expect(
            LoginItemManager.unavailableReason(for: app) == nil
        )
        #expect(
            LoginItemManager.unavailableReason(for: translocated)
                == .translocated
        )
        #expect(
            LoginItemManager.unavailableReason(for: bareBinary)
                == .notBundled
        )
    }

    @Test("the switch reads on for enabled and awaiting-approval")
    func isOnDerivation() {
        // `.requiresApproval` counts as on: the user said yes,
        // macOS just hasn't confirmed it yet.
        #expect(LoginItemState.enabled.isOn)
        #expect(LoginItemState.requiresApproval.isOn)
        #expect(!LoginItemState.notRegistered.isOn)
        #expect(!LoginItemState.unavailable(.notBundled).isOn)
        #expect(!LoginItemState.unavailable(.translocated).isOn)
    }
}
