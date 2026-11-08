import Foundation
import Testing

@testable import KiwiDeskCore

/// The touch reader stays one, behind one door, and out of the
/// test run (#1873 ruling ▸ Reader).
///
/// What each clause keeps, because `TouchGesturesTests`' fake
/// reader sees none of it:
/// - ONE live factory, in `TouchGestures`, pinned inert in both
///   `makeTestCore` twins — the #565 class: the seeds bind touch
///   slots on every core, so a forgotten pin starts a reader of
///   the developer's trackpad in every suite.
/// - the framework's callables are reached only from the reader
///   and its own home, so a second caller cannot register a
///   device beside the one `stop` unregisters.
///
/// Residue: the pin clause reads the twins' text, not that
/// `makeTestCore` reaches the line.
@Suite("The touch reader stays one, behind its door")
struct TouchReaderSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let productionTrees = [
        root.appendingPathComponent("Sources/KiwiDeskCore"),
        root.appendingPathComponent("Sources/KiwiDesk"),
    ]

    private static func files(of needle: String) throws -> [String] {
        try productionTrees.flatMap {
            try SourceScan.identifierSites(of: needle, under: $0)
        }.map(\.file.lastPathComponent)
    }

    @Test("one live factory, pinned inert in both twins")
    func liveFactoryPinned() throws {
        #expect(
            try Self.files(of: "TouchReader.live(") == [
                "TouchGestures.swift"
            ]
        )
        for target in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let twin = Self.root.appendingPathComponent(
                "Tests/\(target)/TestCore.swift"
            )
            let source = try SourceScan.strippedSource(at: twin)
            #expect(
                source.contains("mouse.trackpad.makeReader = { _ in nil }"),
                "\(target)"
            )
            #expect(
                source.contains("mouse.trackpad.readSystemGestures"),
                "\(target)"
            )
        }
    }

    @Test("the session's return rebuilds the reader")
    func returnRearms() throws {
        let source = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore/App/KiwiCore+Bootstrap.swift"
            )
        )
        // The closure the session's return runs, up to its brace.
        let start = try #require(
            source.range(of: "sleepWake.onReturn = {")
        )
        let closure = source[start.upperBound...]
            .prefix { $0 != "}" }
        #expect(closure.contains("mouse.trackpad.rearm()"))
    }

    @Test("the framework's callables are the reader's alone")
    func callablesHaveOneCaller() throws {
        for symbol in [
            "registerSymbol.function", "unregisterSymbol.function",
            "startSymbol.function", "stopSymbol.function",
        ] {
            let homes = Set(try Self.files(of: symbol))
            #expect(
                homes.isSubset(of: [
                    "TouchReader.swift", "MultitouchSupport.swift",
                ]),
                "\(symbol): \(homes.sorted())"
            )
            #expect(homes.contains("TouchReader.swift"), "\(symbol)")
        }
    }
}
