import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The test desk's seams the runner cannot reach (#3121): the
/// runner is never a test desk, so `MachineLocation.directory` is
/// the default one there and a lock moved under it passes every
/// behaviour suite. Each clause reads the one site that decides.
@Suite("Test desk seams (#3121)")
struct TestDeskSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: root.appendingPathComponent(path)
        )
    }

    /// The body after `opening`, up to its first closing brace.
    private static func body(
        after opening: String,
        in text: String
    ) throws -> Substring {
        let start = try #require(text.range(of: opening))
        let rest = text[start.upperBound...]
        let end = try #require(rest.firstIndex(of: "}"))
        return rest[..<end]
    }

    @Test("every instance takes the default folder's lock")
    func lockStaysDefault() throws {
        let text = try Self.source(
            "Sources/KiwiDeskCore/App/MachineLocation.swift"
        )
        let lock = try Self.body(
            after: "public static var lockPath: String {",
            in: text
        )
        #expect(
            lock.trimmingCharacters(in: .whitespacesAndNewlines)
                == "lock(in: defaultDirectory).path"
        )
    }

    @Test("both lock losses refuse on a test desk")
    func lockLossRefuses() throws {
        let main = try Self.source("Sources/KiwiDesk/main.swift")
        #expect(
            main.components(separatedBy: "lostTheInstanceLock()")
                .count - 1 == 2
        )
        #expect(!main.contains("surfaceRunningInstanceAndExit("))
        let guardText = try Self.source(
            "Sources/KiwiDesk/SingleInstanceGuard.swift"
        )
        let loss = try Self.body(
            after: "func lostTheInstanceLock() -> Never {",
            in: guardText
        )
        let refusal = try #require(
            loss.range(of: "if TestDesk.isActive {")
        )
        #expect(loss[refusal.upperBound...].contains("exit(1)"))
    }

    @Test("a test desk refuses every service verb but status")
    func serviceRefusesButStatus() {
        for action in ServiceAction.allCases {
            let refused = action.refusal(active: true) != nil
            #expect(refused == (action != .status), "\(action)")
            #expect(action.refusal(active: false) == nil, "\(action)")
        }
    }

    @Test("the service door asks the refusal")
    func serviceAsksTheRefusal() throws {
        let cli = try Self.source("Sources/KiwiDesk/CLIMain.swift")
        #expect(cli.contains("if let refusal = action.refusal() {"))
    }
}
