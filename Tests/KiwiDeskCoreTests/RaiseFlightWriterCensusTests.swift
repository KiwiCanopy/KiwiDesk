import Foundation
import Testing

/// A `RaiseFlight` (#1812) is written by the `focus` verb's
/// wrapper alone: three review rounds went to re-assert paths
/// that rewrote it inside `focusWindow`, naming the app the user
/// switched to as the one left. Every construction and every
/// whole-record assignment in Core lives in the preflight file;
/// a raise path only restamps (`raised`) or rekeys (`rekey`).
@Suite("Raise flight has one writer")
struct RaiseFlightWriterCensusTests {
    private static let home =
        "Commands/KiwiCore+FocusedCommandGuard.swift"
    /// A construction — the bare type name, never `endRaiseFlight(`
    /// — or a whole-record assignment, never `==`.
    private static let writer = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z])RaiseFlight\(|\braiseFlight\s*=(?!=)"#
    )

    @Test("only the preflight file builds or assigns a flight")
    func oneWriterFile() throws {
        let core = scriptFixtureRepoRoot()
            .appendingPathComponent("Sources/KiwiDeskCore")
        let files = try #require(
            FileManager.default.enumerator(atPath: core.path)
        )
        var writers: [String: Int] = [:]
        for case let path as String in files
        where path.hasSuffix(".swift") {
            let text = try String(
                contentsOf: core.appendingPathComponent(path),
                encoding: .utf8
            )
            let hits = text.split(separator: "\n").filter { line in
                let code =
                    line.split(
                        separator: "//",
                        maxSplits: 1,
                        omittingEmptySubsequences: false
                    ).first ?? ""
                return Self.writer.firstMatch(
                    in: String(code),
                    range: NSRange(code.startIndex..., in: code)
                ) != nil
            }.count
            if hits > 0 { writers[path] = hits }
        }
        #expect(writers[Self.home] == 2, "\(writers)")
        #expect(Set(writers.keys) == [Self.home], "\(writers)")
    }
}
