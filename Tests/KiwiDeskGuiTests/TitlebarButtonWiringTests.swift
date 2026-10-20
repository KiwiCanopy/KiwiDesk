import Foundation
import Testing

/// Every reader that asks whether the ignore gate reads a title-bar
/// button hands it the app's bundle id and the window's subrole, or
/// Ghostty's escape (#2067) or the system-dialog narrowing (#2239)
/// stops at that reader while every pure test stays green.
@Suite("Title-bar button wiring (#2067)")
struct TitlebarButtonWiringTests {
    private static let events = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore/Events")

    /// The call's arguments, up to its own closing paren.
    private func arguments(
        in file: String,
        of call: String = "FloatDetection.needsTitlebarButton("
    ) throws -> [Substring] {
        let source = try SourceScan.strippedSource(
            at: Self.events.appendingPathComponent(file)
        )
        var found: [Substring] = []
        var rest = source[...]
        while let call = rest.range(of: call) {
            let tail = rest[call.upperBound...]
            var depth = 0
            let close =
                tail.firstIndex {
                    if $0 == "(" { depth += 1 }
                    if $0 == ")" { depth -= 1 }
                    return depth < 0
                } ?? tail.endIndex
            found.append(tail[..<close])
            rest = tail[close...]
        }
        return found
    }

    @Test("each reader passes the bundle id and the subrole")
    func readersPassTheBundleID() throws {
        let readers = [
            "EventLoop+ListedWindows.swift": [
                "bundleID: bundleID", "subrole: facts.subrole",
            ],
            "EventLoop+WindowPolicy.swift": [
                "bundleID: app.bundleID",
                "subrole: subrole ?? AXHelper.subrole(of: element)",
            ],
            "EventLoop+UntrackedFocus.swift": [
                "bundleID: bundleID", "subrole: AXHelper.subrole(of: $0)",
            ],
        ]
        for (file, needles) in readers {
            let calls = try arguments(in: file)
            #expect(calls.count == 1, "\(file)")
            for needle in needles {
                #expect(
                    calls.allSatisfy { $0.contains(needle) },
                    "\(file): \(needle)"
                )
            }
        }
        var total = 0
        for file in try SourceScan.swiftSources(under: Self.events) {
            total += try SourceScan.strippedSource(at: file)
                .occurrences(of: "FloatDetection.needsTitlebarButton(")
        }
        #expect(total == readers.count)
    }

    /// A caller of the gate's `shouldIgnore` hands it the subrole it
    /// already read, or the gate re-reads it live beside the
    /// reading the rest of adoption judged on (#2239).
    @Test("the gate's callers hand it the subrole they read")
    func gateCallersPassTheSubrole() throws {
        let callers = [
            "EventLoop+Tracking.swift": "subrole: subrole,",
            "EventLoop+Reconcile.swift": "subrole: read?.subrole,",
        ]
        for (file, needle) in callers {
            let calls = try arguments(in: file, of: "shouldIgnore(\n")
            #expect(calls.count == 1, "\(file)")
            #expect(calls.allSatisfy { $0.contains(needle) }, "\(file)")
        }
    }
}
