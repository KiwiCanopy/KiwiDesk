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
/// The local arm must stay press bookkeeping ONLY, and since
/// the fan-out moved inside `recordDown` that is a property of
/// the press's own `Origin` — held behaviourally by
/// `OwnWindowGestureDeliveryTests.fanOutHearsOtherAppsAlone`,
/// which is the primary guard. What survives here is the net
/// beside it: exactly one `onLeftMouseDown` call site, so a
/// SECOND one added anywhere — under no gate, or under an
/// inverted one — cannot slip past the behavioural test by
/// living somewhere it never looks. The consumers that stand
/// down are built on a global monitor's blindness to our own
/// windows: `followDisplayUnderClick` takes its bar-overlay
/// exemption from it (#446), and `lastLeftClick` is the click
/// provenance the cross-display sibling distrust (#496, #687)
/// and the ignored-panel escape (#951) read.
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

    /// How many times `kind` is installed in `body`.
    private func sites(of kind: String, in body: String) -> Int {
        body.occurrences(of: kind + "(")
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
            // One installation per event, derived from the
            // events themselves: a single monitor declared
            // `matching: [.leftMouseDown, .leftMouseUp]` covers
            // the cross product while being exactly the shape
            // that cannot carry the arms' asymmetry.
            #expect(
                sites(of: kind, in: body) == events.count,
                Comment(
                    rawValue: "\(kind) is installed "
                        + "\(sites(of: kind, in: body)) times, "
                        + "not once per button event"
                )
            )
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

    @Test("The click fan-out has one call site")
    func oneFanOutCallSite() throws {
        let text = try source()
        let calls =
            text.components(
                separatedBy: "onLeftMouseDown?("
            ).count - 1
        let why =
            "`onLeftMouseDown` has \(calls) call sites. One, "
            + "so the origin gate inside `recordDown` cannot "
            + "be bypassed by a second site — "
            + "`fanOutHearsOtherAppsAlone` guards the gate "
            + "itself, never a site it never looks at."
        #expect(calls == 1, Comment(rawValue: why))
    }
}
