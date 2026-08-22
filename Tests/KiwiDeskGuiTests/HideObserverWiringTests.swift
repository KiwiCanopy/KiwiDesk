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

    /// The registration block: from the first hide observer to
    /// the line that retains the tokens. The claims below are
    /// scoped to it, because a file-wide count is satisfiable
    /// from anywhere — proven, not theorised: unwiring the
    /// unhide closure and adding one unrelated
    /// `appHideChanged(` mention elsewhere in the file restored
    /// a whole-file count and left the suite green with the
    /// unhide direction dead.
    private func registrationBlock() throws -> Substring {
        let text = try appsSource()
        let from = try #require(
            text.range(of: "didHideApplicationNotification")
        )
        let to = try #require(
            text.range(of: "workspaceTokens = [")
        )
        try #require(from.lowerBound < to.lowerBound)
        return text[from.lowerBound..<to.lowerBound]
    }

    @Test("both registrations reach the funnel")
    func bothRegistrationsCallTheArm() throws {
        // Two call sites, because the two closures are separate
        // — registering both notifications and wiring only one
        // of them to `appHideChanged` is a live failure mode
        // that the needle above alone would miss.
        let block = try registrationBlock()
        let calls =
            block.components(
                separatedBy: "appHideChanged("
            ).count - 1
        #expect(calls == 2)
    }

    @Test("every registered observer is retained for teardown")
    func tokensAreRetained() throws {
        // An observer token dropped on the floor is never
        // deregistered — `workspaceTokens` is what
        // `EventLoop+Lifecycle` walks, so a registration missing
        // from that array leaks a live observer past a stop.
        //
        // DERIVED, not listed. The first draft asked whether the
        // array contained "hide" and "unhide", and the first is
        // a substring of the second: dropping `hide` from the
        // array left this suite green with the didHide observer
        // leaking past every `stop()`. A hand-listed pair also
        // has to be updated for the next observer, which is the
        // copy rule-authoring.md ▸ "a number-pin must derive the
        // number" refuses. So parse the bindings the function
        // creates, parse the array, and require the first set
        // inside the second.
        let text = try appsSource()
        var registered: Set<String> = []
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(
                in: .whitespaces
            )
            guard trimmed.hasPrefix("let "),
                trimmed.contains("center.addObserver")
            else { continue }
            let name =
                trimmed
                .dropFirst("let ".count)
                .prefix { $0.isLetter || $0.isNumber }
            registered.insert(String(name))
        }
        // Fail-shut: no bindings parsed means the shape moved,
        // and an empty set is a subset of anything.
        try #require(registered.count >= 2)

        let at = try #require(
            text.range(of: "workspaceTokens = [")
        )
        let after = text[at.upperBound...]
        let close = try #require(after.firstIndex(of: "]"))
        let retained = Set(
            after[..<close]
                .split(separator: ",")
                .map {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
                .filter { !$0.isEmpty }
        )
        #expect(registered.subtracting(retained).isEmpty)
    }
}
