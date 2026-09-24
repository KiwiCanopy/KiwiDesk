import Foundation
import Testing

/// Forwarding a dropped Space's windows into a fallback is ONE
/// primitive, `KiwiCore.forwardWindows(of:to:)` (#1177): the
/// membership write, the display-crossing re-anchor (#444) and
/// the re-file record each ride it, and a hand copy of that step
/// list is how `delete_space` shipped without the record while
/// the prune carried it. The lens: the Space drop itself
/// (`workspaces.removeSpace(`) is spelled in Core exactly once,
/// inside the primitive's file, and the primitive is called from
/// the prune and the delete verb.
@Suite("Space forwarding seam")
struct SpaceForwardingSeamTests {
    private static let home = "Profiles/KiwiCore+ProfileSpaces.swift"

    @Test("the Space drop is spelled once, inside the primitive")
    func removeSpaceHasOneHome() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let prefix = root.path + "/"
        var homes: [String: Int] = [:]
        var callers: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let key = String(file.path.dropFirst(prefix.count))
            let source = try SourceScan.strippedSource(at: file)
            let drops = source.occurrences(of: "workspaces.removeSpace(")
            if drops > 0 { homes[key] = drops }
            let calls = source.occurrences(of: "forwardWindows(of:")
            if calls > 0 { callers[key] = calls }
        }
        #expect(homes == [Self.home: 1])
        // The callers (the definition spells its labels with
        // parameter names, so the call needle misses it) — the
        // boot's placeholder retirement the third (#1526).
        #expect(
            callers == [
                "Profiles/KiwiCore+ProfileResolution.swift": 1,
                "Commands/KiwiCore+SpaceLifecycleCommands.swift": 1,
                "App/KiwiCore+PlaceholderSpace.swift": 1,
            ]
        )
    }
}
