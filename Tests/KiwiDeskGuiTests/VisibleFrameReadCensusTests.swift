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

    /// Member reads of `.visibleFrame` in `text` — a routed
    /// `GeometryUtils.visibleFrame(of:)` call is not one. Blind to
    /// an implicit-`self` read inside an `NSScreen` extension, which
    /// `kiwiDisplayIsCorrected` holds for the one extension there is.
    private static func rawReads(in text: String) -> Int {
        var count = 0
        var cursor = text.startIndex
        while let hit = text.range(
            of: ".visibleFrame",
            range: cursor..<text.endIndex
        ) {
            cursor = hit.upperBound
            if text[hit.upperBound...].hasPrefix("(") { continue }
            count += 1
        }
        return count
    }

    private func coreSources() throws -> [URL] {
        let files = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore"
            )
        )
        #expect(!files.isEmpty)
        return files
    }

    @Test("no unrouted .visibleFrame read in Core")
    func noUnroutedRead() throws {
        var offenders: [String] = []
        for file in try coreSources() {
            let name = file.lastPathComponent
            guard Self.allowed[name] == nil else { continue }
            let text = try SourceScan.strippedSource(at: file)
            if Self.rawReads(in: text) > 0 { offenders.append(name) }
        }
        #expect(
            offenders.isEmpty,
            .init(rawValue: "unrouted read in \(offenders)")
        )
    }

    @Test("every allowed file still reads it raw")
    func allowedIsLive() throws {
        let files = try coreSources()
        for name in Self.allowed.keys {
            let file = try #require(
                files.first { $0.lastPathComponent == name }
            )
            let text = try SourceScan.strippedSource(at: file)
            #expect(
                Self.rawReads(in: text) > 0,
                .init(rawValue: "\(name) no longer reads it")
            )
        }
    }

    /// The Display snapshot the quit grid reads is filled from the
    /// derivation, not the bare member it would read by default.
    @Test("the Display snapshot takes the corrected frame")
    func kiwiDisplayIsCorrected() throws {
        let file = try #require(
            coreSources().first {
                $0.lastPathComponent == "EventLoop+Apps.swift"
            }
        )
        let text = try SourceScan.strippedSource(at: file)
        let body = try #require(
            SourceScan.declarationBody(
                after: "var kiwiDisplay: Display?",
                in: text
            )
        )
        #expect(
            body.contains(
                "visibleFrame: GeometryUtils.visibleFrame(of: self)"
            )
        )
    }
}
