import Foundation
import Testing

/// Jump's full-screen raise goes around the #1345 gate on purpose
/// (#2939), so it is reachable from Jump alone: the ordered raise is
/// spelled once, as the seam's default, the seam is called only by
/// the arm, and the arm only by Jump. An implicit raise
/// reaching it would switch the user onto a full-screen Space
/// nobody asked for. Comment-stripped needles,
/// spelled as the call; the arm's own definition is subtracted.
/// Here because `SourceScan` scans both trees (AGENTS.md §1).
@Suite("Jump's full-screen raise census (#2939)")
struct JumpFullScreenSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let core = root.appendingPathComponent(
        "Sources/KiwiDeskCore"
    )

    /// Call counts of `needle` per Core file, less `definition`.
    private func calls(
        _ needle: String,
        less definition: String? = nil
    ) throws -> [String: Int] {
        var found: [String: Int] = [:]
        let walker = FileManager.default.enumerator(
            at: Self.core,
            includingPropertiesForKeys: nil
        )
        while let url = walker?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            let count =
                occurrences(of: needle, in: source)
                - (definition.map { occurrences(of: $0, in: source) } ?? 0)
            if count > 0 { found[url.lastPathComponent] = count }
        }
        return found
    }

    private func occurrences(of needle: String, in source: String) -> Int {
        source.components(separatedBy: needle).count - 1
    }

    @Test("the ordered raise is spelled once, as the seam's default")
    func raiseHasOneHome() throws {
        #expect(
            try calls("AXHelper.activateThenRaise(")
                == ["KiwiCore+LaunchRestore.swift": 1]
        )
    }

    @Test("the seam is called by the arm alone")
    func seamHasOneCaller() throws {
        #expect(
            try calls("openOrFocus.raiseFullScreen(")
                == ["KiwiCore+JumpFullScreen.swift": 1]
        )
    }

    @Test("the arm is called by Jump alone")
    func armHasOneCaller() throws {
        #expect(
            try calls(
                "jumpToFullScreen(",
                less: "func jumpToFullScreen("
            ) == ["KiwiCore+JumpActions.swift": 2]
        )
    }

    /// The live default activates a real app, so both twins pin it.
    @Test("both test twins pin the seam")
    func twinsPinTheSeam() throws {
        for twin in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let url = Self.root.appendingPathComponent(
                "Tests/\(twin)/TestCore.swift"
            )
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            #expect(
                source.contains(
                    "core.openOrFocus.raiseFullScreen = { _, _, _ in false }"
                ),
                "\(twin) leaves the live raise"
            )
        }
    }
}
