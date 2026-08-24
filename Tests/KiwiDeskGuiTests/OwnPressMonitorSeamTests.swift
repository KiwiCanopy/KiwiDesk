import Foundation
import Testing

/// Issue #953: `MouseTracker` watches the left button through
/// TWO monitor kinds, and the asymmetry between them is
/// load-bearing in both directions — neither half is observable
/// from a test process, since a monitor only fires on real
/// input.
///
/// The local arm exists because a global monitor never sees an
/// event routed to our OWN windows: without it the tiled
/// Settings window was the one tiled window whose drags had no
/// recorded press, so neither `isResizeGesture`'s trailing-event
/// branch nor the live resize-vs-move gate could classify its
/// gesture.
///
/// The local arm must stay press bookkeeping ONLY. Firing
/// `onLeftMouseDown` from it would silently re-aim three
/// consumers built on the global monitor's blindness:
/// `followDisplayUnderClick` takes its bar-overlay exemption
/// from that blindness (#446), and `lastLeftClick` is the click
/// provenance the cross-display sibling distrust (#496, #687)
/// and the ignored-panel escape (#951) read. Widening the
/// fan-out is a ruling those issues own, not a side effect of
/// making a gesture classifiable.
@Suite("Own-window press monitor seam (#953)")
struct OwnPressMonitorSeamTests {
    private var tracker: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Events/MouseTracker.swift"
            )
    }

    private func source() throws -> String {
        try SourceScan.strippedSource(at: tracker)
    }

    @Test("Both monitor kinds are installed")
    func bothMonitorKindsInstalled() throws {
        let text = try source()
        #expect(
            text.contains("addGlobalMonitorForEvents"),
            "the global arm watches every other app's presses"
        )
        #expect(
            text.contains("addLocalMonitorForEvents"),
            "the local arm watches our own windows' presses"
        )
    }

    @Test("Only one arm feeds the click fan-out")
    func oneFanOutCallSite() throws {
        let text = try source()
        let calls =
            text.components(
                separatedBy: "onLeftMouseDown?("
            ).count - 1
        let why =
            "`onLeftMouseDown` is fired from the GLOBAL arm "
            + "alone: #446, #496, #687 and #951 read "
            + "consumers built on that monitor never seeing "
            + "our own windows' clicks. Found \(calls)."
        #expect(calls == 1, Comment(rawValue: why))
    }
}
