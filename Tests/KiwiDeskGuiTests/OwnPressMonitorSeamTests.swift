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
    /// The two axes a monitor installation sits on. Every pair
    /// of them must exist in `start()` — the assertion is the
    /// CROSS PRODUCT, never a hand-written count of monitors: a
    /// count of four is satisfied by four of the wrong ones,
    /// which is how the first draft of this guard stayed green
    /// while the local `.leftMouseDown` arm — the absence that
    /// IS #953 — was deleted (guard-prover, 2026-08-24).
    private let kinds = [
        "addGlobalMonitorForEvents",
        "addLocalMonitorForEvents",
    ]
    private let events = [".leftMouseDown", ".leftMouseUp"]

    private var tracker: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Events/MouseTracker.swift"
            )
    }

    private func source() throws -> String {
        try SourceScan.strippedSource(at: tracker)
    }

    /// Which events each monitor kind is installed for, read
    /// from the argument group of every installation in
    /// `start()`.
    private func installed(
        in body: String
    ) -> Set<String> {
        let characters = Array(body)
        var pairs: Set<String> = []
        for kind in kinds {
            let marker = Array(kind)
            var index = 0
            while index + marker.count <= characters.count {
                guard
                    Array(
                        characters[index..<(index + marker.count)]
                    ) == marker
                else {
                    index += 1
                    continue
                }
                var cursor = index + marker.count
                let arguments =
                    SourceScan.balanced(
                        characters,
                        from: &cursor,
                        open: "(",
                        close: ")"
                    ) ?? ""
                for event in events
                where
                    arguments.contains(event)
                {
                    pairs.insert("\(kind) \(event)")
                }
                index = max(cursor, index + marker.count)
            }
        }
        return pairs
    }

    @Test("Every monitor kind watches every button event")
    func bothMonitorKindsInstalled() throws {
        let body = try SourceScan.functionBody(
            of: "start",
            in: "MouseTracker.swift",
            under: "Events"
        )
        #expect(!body.isEmpty, "start() body not found")
        let found = installed(in: body)
        for kind in kinds {
            for event in events {
                let pair = "\(kind) \(event)"
                #expect(
                    found.contains(pair),
                    Comment(
                        rawValue: "start() installs no \(pair) "
                            + "monitor. The local arm is what "
                            + "records our own windows' presses "
                            + "(#953); the global arm is every "
                            + "other app's."
                    )
                )
            }
        }
    }

    @Test("The local arm records only the marked window")
    func localArmGatesOnTheTilingMark() throws {
        let body = try SourceScan.functionBody(
            of: "start",
            in: "MouseTracker.swift",
            under: "Events"
        )
        #expect(!body.isEmpty, "start() body not found")
        #expect(
            body.contains("tilingWindowPress"),
            Comment(
                rawValue: "the local arm must record a "
                    + "press only when it landed in the "
                    + "one own window carrying "
                    + "OwnWindowTiling.identifier — per "
                    + "WINDOW, never per process (#678 "
                    + "item 18)"
            )
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
