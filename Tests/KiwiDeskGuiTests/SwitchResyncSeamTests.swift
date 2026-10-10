import Foundation
import Testing

/// The Desktop switch's wirings no unit test reaches: the
/// notification handler that runs the re-sync is private to the
/// event loop, and the Settings refresh rides a workspace
/// notification no fixture posts. `SwitchResyncFoldTests` holds
/// what the fold does; this holds that the switch still takes it,
/// and that Settings re-renders after the switch's turn rather
/// than inside it. Each needle is pinned by exact count to its
/// file: a second fold site is harmless, zero is the lag back.
@Suite("The Desktop switch's re-sync stays folded")
struct SwitchResyncSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// needle → (tree, the file that carries it, how often).
    private static let wirings: [(String, String, String, Int)] = [
        // The switch handler runs its re-sync through the seam.
        (
            "foldsSwitchResync { reconcileAll() }",
            "Sources/KiwiDeskCore", "EventLoop+Apps.swift", 1
        ),
        // Bootstrap wires the seam to the fold.
        (
            "self.foldingSwitchResync(body)",
            "Sources/KiwiDeskCore", "KiwiCore+Bootstrap.swift", 1
        ),
        // The event retile asks the fold before it retiles.
        (
            "!foldIntoSwitchResync()",
            "Sources/KiwiDeskCore", "KiwiCore+Events.swift", 1
        ),
        // The close-return raise and its track arm wait for the
        // fold's one pass.
        (
            "afterSwitchResync { [self] in",
            "Sources/KiwiDeskCore", "KiwiCore+CloseReturn.swift", 2
        ),
    ]

    @Test("each wiring exists exactly once, in its own file")
    func wiringsAreSingular() throws {
        for (needle, tree, file, count) in Self.wirings {
            let sites = try SourceScan.identifierSites(
                of: needle,
                under: Self.root.appendingPathComponent(tree)
            )
            #expect(
                sites.count == count
                    && sites.allSatisfy {
                        $0.file.lastPathComponent == file
                    },
                """
                expected \(count) `\(needle)` in \(file), found: \
                \(sites.map(\.site).joined(separator: ", "))
                """
            )
        }
    }

    /// Comment-free source with every whitespace dropped, so a
    /// needle pins what a closure CONTAINS, not only that one
    /// exists beside the call.
    private static func squeezed(_ path: String) throws -> String {
        let url = root.appendingPathComponent(path)
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .filter { !$0.isWhitespace }
    }

    @Test("the close-return raise and track arm sit inside the wait")
    func closeReturnWorkIsInsideTheWait() throws {
        let source = try Self.squeezed(
            "Sources/KiwiDeskCore/App/KiwiCore+CloseReturn.swift"
        )
        #expect(
            source.contains(
                "afterSwitchResync{[self]iniflet"
                    + "owedSpace{followSwitch(to:owedSpace,focusing:next)}"
                    + "else{focusWindow(next,warp:true)}"
                    + "armCloseReturnRestack(to:next,"
                    + "fromRemovedSlot:removedSlot)}"
            )
        )
        #expect(
            source.contains(
                "afterSwitchResync{[self]in"
                    + "scheduleTrackZOrderRestoreIfOverflowing()}"
            )
        )
    }

    /// The topology refresh is hopped to the next main turn, so
    /// the re-render it starts never joins the switch's turn.
    @Test("Settings refreshes after the switch's turn")
    func settingsRefreshIsDeferred() throws {
        let source = try Self.squeezed(
            "Sources/KiwiDesk/Settings/SettingsWindowController.swift"
        )
        #expect(
            source.contains(
                "DispatchQueue.main.async{MainActor.assumeIsolated"
                    + "{self?.refreshProfiles()}}"
            )
        )
        #expect(
            source.components(separatedBy: "self?.refreshProfiles()")
                .count == 2
        )
    }
}
