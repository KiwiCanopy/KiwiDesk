import Foundation
import Testing

/// A list read takes its layers one window at a time (#2531). The
/// public window list waits on this process's pending window
/// updates while holding the WindowServer connection lock, and the
/// ring's commit on the main actor waited ~500 ms behind it, so the
/// list read's files ask the server through `layerReader` alone.
@Suite("List layer read seams (#2531)")
struct ListLayerReadSeamTests {
    private static var core: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    private static func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: core.appendingPathComponent(path)
        )
    }

    /// The files a list read runs through, off the main actor or
    /// on it, and the reads that wait on the public window list.
    private static let listReadFiles = [
        "Events/EventLoop+ListedWindows.swift",
        "Events/EventLoop+ReconcileOffMain.swift",
        "Events/EventLoop+SwitchReconcile.swift",
        "Events/EventLoop+Reconcile.swift",
    ]
    private static let wholeListReads = [
        "CGWindowListCopyWindowInfo", "windowLayers",
        "serverSnapshot", "onScreenNormalWindowIDs",
        "frontToBackWindows",
    ]

    @Test("a list read names no public window-list read")
    func listReadFilesTakeTheReader() throws {
        for file in Self.listReadFiles {
            let text = try Self.source(file)
            #expect(!text.isEmpty, "\(file) read empty")
            for read in Self.wholeListReads {
                #expect(!text.contains(read), "\(file) reads \(read)")
            }
        }
    }

    /// The whole app's layers have one reader: the fallback.
    @Test("the whole-list layer read has one caller")
    func wholeListReadHasOneCaller() throws {
        var callers: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: Self.core) {
            let text = try SourceScan.strippedSource(at: file)
            let hits =
                text.components(separatedBy: "windowLayers")
                .count - 1
            if hits > 0 { callers[file.lastPathComponent] = hits }
        }
        // The declaration and the fallback's call.
        #expect(callers == ["FloatDetection+Ignore.swift": 2])
    }

    @Test("both list paths read layers through the reader")
    func listPathsTakeTheReader() throws {
        let offMain = try Self.source(
            "Events/EventLoop+ReconcileOffMain.swift"
        ).filter { !$0.isWhitespace }
        #expect(
            offMain.contains(
                "varreadLayers:(pid_t)->(WindowID)->Int?="
                    + "FloatDetection.layerReader"
            )
        )
        let reconcile = try Self.source(
            "Events/EventLoop+Reconcile.swift"
        )
        #expect(reconcile.contains("FloatDetection.layerReader(pid:"))
    }

    /// The level answers first, in both one-window readers; the
    /// public read is only what it does not answer.
    @Test("the readers ask SkyLight's level before the public list")
    func readersPreferTheLevel() throws {
        let readers = [
            (
                "AX/FloatDetection+Ignore.swift",
                "static func layerReader(", "windowLayers(pid:"
            ),
            (
                "AX/FloatDetection.swift",
                "func windowLayer(of", "serverSnapshot(of:"
            ),
        ]
        for (file, declaration, fallback) in readers {
            let body = String(
                try #require(
                    SourceScan.declarationBody(
                        after: declaration,
                        in: try Self.source(file)
                    ),
                    "\(declaration) is gone"
                )
            )
            let level = try #require(
                body.range(of: "SkyLight.windowLevel(")
            )
            let listRead = try #require(body.range(of: fallback))
            #expect(level.lowerBound < listRead.lowerBound, "\(file)")
        }
    }
}
