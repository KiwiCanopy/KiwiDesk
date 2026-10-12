import Foundation
import Testing

/// Every reader that asks whether the ignore gate reads a title-bar
/// button hands it the app's bundle id, or Ghostty's escape (#2067)
/// stops at that reader while every pure test stays green.
@Suite("Title-bar button wiring (#2067)")
struct TitlebarButtonWiringTests {
    private static let events = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore/Events")

    /// The call's arguments, up to its closing paren.
    private func arguments(in file: String) throws -> [Substring] {
        let source = try SourceScan.strippedSource(
            at: Self.events.appendingPathComponent(file)
        )
        var found: [Substring] = []
        var rest = source[...]
        while let call = rest.range(
            of: "FloatDetection.needsTitlebarButton("
        ) {
            let tail = rest[call.upperBound...]
            let close = tail.firstIndex(of: ")") ?? tail.endIndex
            found.append(tail[..<close])
            rest = tail[close...]
        }
        return found
    }

    @Test("each reader passes the app's bundle id")
    func readersPassTheBundleID() throws {
        let readers = [
            "EventLoop+ListedWindows.swift": "bundleID: bundleID",
            "EventLoop+WindowPolicy.swift": "bundleID: app.bundleID",
            "EventLoop+UntrackedFocus.swift": "bundleID: bundleID",
        ]
        for (file, needle) in readers {
            let calls = try arguments(in: file)
            #expect(calls.count == 1, "\(file)")
            #expect(calls.allSatisfy { $0.contains(needle) }, "\(file)")
        }
        var total = 0
        for file in try SourceScan.swiftSources(under: Self.events) {
            total += try SourceScan.strippedSource(at: file)
                .occurrences(of: "FloatDetection.needsTitlebarButton(")
        }
        #expect(total == readers.count)
    }
}
