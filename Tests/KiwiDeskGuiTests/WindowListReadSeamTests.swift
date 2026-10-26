import Foundation
import Testing

/// The public window list has one door (#2634): every read names
/// its call site through `WindowListRead.copy`, so a slow read is
/// attributed in the log. A bare call beside it reads unnamed.
@Suite("Window-list read door (#2634)")
struct WindowListReadSeamTests {
    private static let trees = ["KiwiDeskCore", "KiwiDesk"].map {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/\($0)")
    }

    /// Both trees; the sibling reads of the same lock-holding class
    /// (`CGWindowListCreate*`) have no caller and take the door's
    /// ruling before one appears.
    private static func hits(of needle: String) throws -> [String: Int] {
        var callers: [String: Int] = [:]
        for tree in trees {
            let files = try SourceScan.swiftSources(under: tree)
            #expect(!files.isEmpty)
            for file in files {
                let text = try SourceScan.strippedSource(at: file)
                let n = text.components(separatedBy: needle).count - 1
                if n > 0 { callers[file.lastPathComponent] = n }
            }
        }
        return callers
    }

    @Test("only the door calls CGWindowListCopyWindowInfo")
    func oneDoor() throws {
        let callers = try Self.hits(of: "CGWindowListCopyWindowInfo(")
        #expect(callers == ["WindowListRead.swift": 1])
    }

    @Test("no sibling window-list read exists")
    func noSiblingRead() throws {
        #expect(try Self.hits(of: "CGWindowListCreate").isEmpty)
    }

    /// The door's own read runs inside `timed`: a bare call left in
    /// `copy` still counts as the one allowed hit above, so the
    /// subject here is the `copy` body, not the file.
    @Test("the door's read is timed")
    func copyTimesItsRead() throws {
        let door = Self.trees[0].appendingPathComponent(
            "OS/WindowListRead.swift"
        )
        let text = try SourceScan.strippedSource(at: door)
        let body = try #require(
            SourceScan.declarationBody(
                after: "static func copy(",
                in: text
            )
        )
        let timed = try #require(body.range(of: "timed("))
        let read = try #require(
            body.range(of: "CGWindowListCopyWindowInfo(")
        )
        #expect(timed.lowerBound < read.lowerBound)
    }
}
