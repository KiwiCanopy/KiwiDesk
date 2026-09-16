import Foundation
import Testing

/// The Monocle flip's production wirings (#1391), which no unit
/// test reaches: WHICH sites take the door. `MonocleFlipDoorTests`
/// holds what the door does; what a fixture cannot see is a
/// commanded site that went back to a bare `focusWindow` — the
/// swap would land instantly and every behavioural suite would
/// stay green — or a fourth caller, an OS-reported focus, that
/// would play a flip over a swap that already happened. Each
/// site is pinned by exact count and to its file.
@Suite("Monocle flip door wiring (#1391)")
struct MonocleFlipSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let core = root.appendingPathComponent(
        "Sources/KiwiDeskCore"
    )
    private static let door = "KiwiCore+MonocleFlip.swift"

    /// The commanded sites: `navigate`'s Monocle cycle, the App
    /// Bar click, and `pull_or_spawn`'s focus of a window in the
    /// active Space — the ruling's list, and nothing reported.
    private static let sites: Set<String> = [
        "KiwiCore+MonocleCommands.swift",
        "KiwiCore+Bootstrap.swift",
        "KiwiCore+LaunchCycle.swift",
    ]

    @Test("The three commanded sites take the door, and no other")
    func commandedSitesTakeTheDoor() throws {
        let hits = try SourceScan.identifierSites(
            of: "focusWithMonocleFlip(",
            under: Self.core
        ).filter { $0.file.lastPathComponent != Self.door }
        let files = hits.map { $0.file.lastPathComponent }
        #expect(
            Set(files) == Self.sites && files.count == 3,
            "door callers: \(hits.map(\.site))"
        )
    }

    /// The door defers `focusWindow` to the midpoint and falls
    /// through to it where no flip plays: two spellings, both in
    /// the door.
    @Test("The door is the one file that pays the focus")
    func doorPaysTheFocus() throws {
        let file = Self.core.appendingPathComponent("App/\(Self.door)")
        let source = try SourceScan.strippedSource(at: file)
        let calls = SourceScan.callSites(
            in: Array(source),
            for: "focusWindow"
        )
        #expect(calls.count == 2, "found \(calls.count)")
    }

    /// A command during a flip lands the pending focus first —
    /// the one settle ahead of dispatch, in the execute wrapper
    /// that is `dispatchCommand`'s one caller.
    @Test("Every command settles a flip ahead of its dispatch")
    func commandsSettleFirst() throws {
        let sites = try SourceScan.identifierSites(
            of: "monocleFlip.settle()",
            under: Self.core
        )
        #expect(
            sites.count == 1
                && sites.first?.file.lastPathComponent
                    == "KiwiCore+Execute.swift",
            "settle sites: \(sites.map(\.site))"
        )
    }
}
