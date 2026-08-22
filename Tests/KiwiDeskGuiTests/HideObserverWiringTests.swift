import Foundation
import Testing

/// The hide/unhide NSWorkspace registrations (#913) — the hunk
/// no behavior suite can red on.
///
/// `HiddenAppWindowTests` drives `appHideChanged` directly and
/// stays green while `registerWorkspaceObservers` stops
/// registering either notification, because every lifecycle
/// suite sets `registersWorkspaceObservers = false` to keep a
/// live workspace observer from outliving a test (tests.md).
/// So the funnel is pinned there and its trigger here — the
/// shape `StartupSweepWiringTests` uses for the same class of
/// gap.
///
/// Both directions, deliberately. Losing `didHide` leaves the
/// tile held until something else reconciles the app, which is
/// the #913 defect wearing a delay; losing `didUnhide` leaves
/// the window unadopted until the census heal's next tick. The
/// second is the quieter failure, so it is the one a needle is
/// actually worth having for.
///
/// Known limits, stated rather than denied (the #635 practice):
/// substring needles over comment-stripped source. A
/// registration moved behind a condition that never holds still
/// matches; deletion is what these red on.
@Suite("Hide observer wiring (#913)")
struct HideObserverWiringTests {
    private func appsSource() throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Events/EventLoop+Apps.swift"
            )
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        // Fail-shut: an empty read passes any needle that only
        // asks for absence, and satisfies none that ask for
        // presence — say so rather than reporting a pass.
        try #require(!text.isEmpty)
        return text
    }

    @Test("both hide notifications are registered")
    func bothDirectionsAreObserved() throws {
        let text = try appsSource()
        #expect(
            text.contains("didHideApplicationNotification")
        )
        #expect(
            text.contains("didUnhideApplicationNotification")
        )
    }

    @Test("both registrations reach the funnel")
    func bothRegistrationsCallTheArm() throws {
        // Two call sites, because the two closures are separate
        // — registering both notifications and wiring only one
        // of them to `appHideChanged` is a live failure mode
        // that the needle above alone would miss.
        let text = try appsSource()
        let calls =
            text.components(
                separatedBy: "appHideChanged("
            ).count - 1
        // Two closures plus the declaration itself.
        #expect(calls == 3)
    }

    @Test("the tokens are retained for teardown")
    func tokensAreRetained() throws {
        // An observer token dropped on the floor is deregistered
        // by `stop()` never — `workspaceTokens` is what
        // `EventLoop+Lifecycle` walks, so a registration missing
        // from that array leaks a live observer past a stop.
        let text = try appsSource()
        let at = try #require(text.range(of: "workspaceTokens = ["))
        let assignment = text[at.lowerBound...].prefix(120)
        #expect(assignment.contains("hide"))
        #expect(assignment.contains("unhide"))
    }
}
