import Foundation
import Testing

/// The off-main list read takes its layers one window at a time
/// (#2531). The whole-list read waits on this process's pending
/// window updates while holding the WindowServer connection lock,
/// and the ring's commit on the main actor waited ~500 ms behind
/// it, so it stays out of every read that runs on a focus change.
@Suite("List layer read seams (#2531)")
struct ListLayerReadSeamTests {
    private static var core: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    /// Who may read a whole app's layers, and why.
    private static let allowed: [String: String] = [
        "FloatDetection+Ignore.swift":
            "its declaration, and the per-window reader's fallback "
            + "where SkyLight has no level read",
        "EventLoop+Reconcile.swift":
            "the main-actor reconcile with no off-main reading, for "
            + "an app with an ignore rule",
    ]

    @Test("the whole-list layer read has its ruled callers only")
    func wholeListReadIsRuled() throws {
        var callers: Set<String> = []
        for file in try SourceScan.swiftSources(under: Self.core) {
            let source = try SourceScan.strippedSource(at: file)
            if source.contains("windowLayers(pid:") {
                callers.insert(file.lastPathComponent)
            }
        }
        #expect(callers == Set(Self.allowed.keys))
    }

    @Test("the off-main read defaults to the per-window reader")
    func offMainSeamIsPerWindow() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "Events/EventLoop+ReconcileOffMain.swift"
            )
        )
        let compact = source.filter { !$0.isWhitespace }
        #expect(
            compact.contains(
                "varreadLayers:(pid_t)->(WindowID)->Int?="
                    + "FloatDetection.layerReader"
            )
        )
    }

    @Test("the per-window reader prefers SkyLight's level read")
    func readerPrefersTheLevel() throws {
        let body = try #require(
            SourceScan.declarationBody(
                after: "static func layerReader(",
                in: try SourceScan.strippedSource(
                    at: Self.core.appendingPathComponent(
                        "AX/FloatDetection+Ignore.swift"
                    )
                )
            ),
            "FloatDetection.layerReader is gone"
        )
        let text = String(body)
        let guardAt = try #require(
            text.range(of: "guard SkyLight.readsWindowLevel else")
        )
        let fallback = try #require(text.range(of: "windowLayers(pid:"))
        let level = try #require(text.range(of: "SkyLight.windowLevel("))
        #expect(guardAt.lowerBound < fallback.lowerBound)
        #expect(fallback.lowerBound < level.lowerBound)
    }
}
