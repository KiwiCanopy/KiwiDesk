import Foundation
import Testing

/// The command half of the cross-screen re-home (#1010), which
/// no behavior suite can red on.
///
/// `ScreenHomePredicateTests` pins what the predicate answers;
/// this pins that `move_to_desktop` ASKS it, and where. Neither
/// end is reachable headlessly: the move itself runs through
/// `WMBridge` (a live WindowServer), and the target screen is
/// resolved by matching display UUIDs through
/// `NativeSpaces.displayUUID(for:)`, which answers only on a
/// machine with those displays attached.
///
/// Two placements are load-bearing, and both are pinned:
///
/// - **After the bridge move succeeded.** A re-home in front of
///   a refused move would file the window into a space on a
///   screen it never reached.
/// - **Before the follow / depart branches.** `switchDesktop`
///   and `departWithoutFollowing` each end in a retile, and
///   that retile is what places the window; membership fixed
///   afterwards would be one retile late, which is the whole
///   defect (the window is dragged home and macOS re-assigns
///   its Desktop to match the frame).
///
/// Here rather than beside the Core suites because `SourceScan`
/// lives in this target and scans both trees (AGENTS.md §1).
///
/// The anchor below deliberately does not spell the bridge
/// type: `WMBridgeSeamTests` holds that a test file naming it
/// reaches a live WindowServer unless it sets the resolver
/// seam, and this suite reads source instead of calling
/// anything. The call site is just as uniquely identified by
/// its arguments.
///
/// Known limit, stated rather than denied (the #635 practice):
/// anchored substrings over comment-stripped source, scoped to
/// the verb's own body rather than read against the whole file.
/// Deletion and reordering are what these red on.
@Suite("Desktop move re-home wiring (#1010)")
struct DesktopMoveRehomeWiringTests {
    private func desktopCommandsSource() throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Commands/"
                    + "KiwiCore+DesktopCommands.swift"
            )
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        // Fail-shut on the scan itself: an empty read finds no
        // anchor, and the require says so out loud rather than
        // passing for having looked at nothing.
        try #require(!text.isEmpty)
        return text
    }

    @Test("the move asks for a re-home once the bridge accepted")
    func theMoveRehomesAfterTheBridge() throws {
        let text = try desktopCommandsSource()
        let bridge = try #require(
            text.range(of: "moveWindows([focused], to: target.space)")
        )
        let call = try #require(
            text.range(
                of: "rehomeAcrossScreens(focused, to: target)",
                range: bridge.upperBound..<text.endIndex
            )
        )
        // Before BOTH branches that end in a retile — the
        // retile is what places the window.
        let follow = try #require(
            text.range(
                of: "if follow {",
                range: bridge.upperBound..<text.endIndex
            )
        )
        #expect(call.upperBound < follow.lowerBound)
    }

    /// The re-home's own body, bounded by the declaration that
    /// follows it rather than by a character count: a negative
    /// needle read against a fixed window silently stops
    /// watching the moment the body grows past it (fail-open),
    /// and one of the assertions below is negative.
    private func rehomeBody(in text: String) throws -> Substring {
        let open = try #require(
            text.range(of: "private func rehomeAcrossScreens")
        )
        let rest = text[open.upperBound...]
        let end =
            rest.range(of: "\n    private func ")?.lowerBound
            ?? rest.range(of: "\n    func ")?.lowerBound
            ?? rest.endIndex
        return rest[..<end]
    }

    @Test("the re-home fires only for a Desktop already shown")
    func theRehomeIsGatedOnTheCurrentDesktop() throws {
        let text = try desktopCommandsSource()
        let scope = try rehomeBody(in: text)
        // The gate is the whole reason the two routes do not
        // overlap. Without it the destination is the space that
        // screen shows NOW, while revealing a hidden Desktop can
        // activate a different one — the membership lands in a
        // space that is not shown, and the reap then remembers
        // it on the arrival's own display, standing the create
        // fold's rule down.
        #expect(scope.contains("guard target.isCurrent else"))
    }

    @Test("the destination comes from the shared predicate")
    func theDestinationIsTheSharedPredicate() throws {
        let text = try desktopCommandsSource()
        let scope = try rehomeBody(in: text)
        // The one copy of the ruling, never a second reading of
        // "which space does that screen show" beside it.
        #expect(scope.contains("state.screenHome("))
        // The target screen is named the way the verbs already
        // name one — by the Desktop's own display UUID, through
        // the shared accessor rather than a fourth hand copy of
        // the match (§2.4).
        #expect(scope.contains("display(forUUID:"))
        #expect(scope.contains("target.displayIdentifier"))
        // Membership only: the verb owns its own focus policy,
        // so the full `moveWindow` command must not appear here.
        #expect(scope.contains("addFocusedToSpace("))
        #expect(!scope.contains("moveWindow("))
        // …plus the destination focus stamp `moveWindow` makes
        // for the #22 reason, and the retile: with `isCurrent`
        // the follow's `switchDesktop` stands down, so nothing
        // else reflows the destination screen.
        #expect(scope.contains("state.workspaces.focus("))
        #expect(scope.contains("retile("))
    }
}
