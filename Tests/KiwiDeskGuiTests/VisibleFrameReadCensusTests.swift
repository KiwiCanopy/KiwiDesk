import Foundation
import Testing

/// `NSScreen.visibleFrame` is AppKit's cache, and it survives a
/// skipped `didChangeScreenParameters` (#1386): a Core reader of a
/// screen's usable area takes `GeometryUtils.visibleFrame(of:)` or
/// `axVisibleFrame(of:)`, which correct it. A member read of
/// `.visibleFrame` outside `allowed` reds until it is routed or
/// given its reason here.
@Suite("visibleFrame read census (#1386)")
struct VisibleFrameReadCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// File → why it may read the member.
    private static let allowed: [String: String] = [
        "GeometryUtils.swift": "the one correcting derivation",
        "DisplayModel.swift": "the Display value's own field",
        "KiwiCore+Teardown.swift":
            "reads the Display snapshot, filled from visibleFrame(of:)",
        "MouseTracker.swift":
            "measures the strip AppKit reserves, auto-hide only",
    ]

    @Test("no unrouted .visibleFrame read in Core")
    func noUnroutedRead() throws {
        let core = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore"
        )
        var offenders: [String] = []
        for file in try SourceScan.swiftSources(under: core) {
            let name = file.lastPathComponent
            guard Self.allowed[name] == nil else { continue }
            let text = try SourceScan.strippedSource(at: file)
            var cursor = text.startIndex
            while let hit = text.range(
                of: ".visibleFrame",
                range: cursor..<text.endIndex
            ) {
                cursor = hit.upperBound
                let rest = text[hit.upperBound...]
                if rest.hasPrefix("(") { continue }
                let lead = text[..<hit.lowerBound].suffix(13)
                if lead == "GeometryUtils" { continue }
                offenders.append(name)
            }
        }
        #expect(
            offenders.isEmpty,
            .init(rawValue: "unrouted read in \(offenders)")
        )
    }

    @Test("every allowed file still reads it")
    func allowedIsLive() throws {
        let core = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore"
        )
        let files = try SourceScan.swiftSources(under: core)
        for name in Self.allowed.keys {
            let file = try #require(
                files.first { $0.lastPathComponent == name }
            )
            let text = try SourceScan.strippedSource(at: file)
            #expect(
                text.contains(".visibleFrame")
                    || text.contains("visibleFrame ="),
                .init(rawValue: "\(name) no longer reads it")
            )
        }
    }
}
