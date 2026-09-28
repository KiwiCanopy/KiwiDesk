import Foundation
import Testing

/// The #1741 crossing's seams, which no behavioural suite can see:
/// one file writes the ledger, and the capture runs before
/// anything that may rewrite a profile file.
@Suite("App-wide settings seams (#1741)")
struct AppWideSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    private func squashed(_ relative: String) throws -> String {
        let raw = try String(
            contentsOf: Self.core.appendingPathComponent(relative),
            encoding: .utf8
        )
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace).joined()
    }

    /// `KiwiCore+AppWide` is the one home of every write; the
    /// declaration is the only other mention.
    @Test("one file touches the ledger")
    func ledgerHasOneHome() throws {
        var touching: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: Self.core) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let count =
                source.components(separatedBy: "appWideLedger").count
                - 1
            if count > 0 { touching[file.lastPathComponent] = count }
        }
        #expect(touching["KiwiCore+AppWide.swift", default: 0] > 0)
        #expect(touching["KiwiCore.swift"] == 1)
        #expect(
            Set(touching.keys)
                == ["KiwiCore+AppWide.swift", "KiwiCore.swift"],
            "the ledger is written outside its home: \(touching)"
        )
    }

    /// The capture reads profile files the #1530 settle may
    /// rewrite without the retired keys.
    @Test("the capture precedes the settle")
    func captureBeforeSettle() throws {
        let body = try squashed("App/KiwiCore+Config.swift")
        let capture = try #require(body.range(of: "prepareAppWide()"))
        let settle = try #require(body.range(of: "settleSharedSets()"))
        #expect(capture.lowerBound < settle.lowerBound)
    }

    /// The adoption ends the crossing at the first apply, ahead of
    /// the outgoing profile's filing.
    @Test("the adoption opens the profile apply")
    func adoptionOpensTheApply() throws {
        let body = try squashed(
            "Profiles/KiwiCore+ProfileResolution.swift"
        )
        let adopt = try #require(
            body.range(of: "adoptAppWide(from:profile)")
        )
        let outgoing = try #require(
            body.range(of: "recordOutgoingPartitioning(")
        )
        #expect(adopt.lowerBound < outgoing.lowerBound)
    }

    /// The resolver's Lua-owned arm is fed the live ownership; a
    /// test building `GeneralGates` itself cannot see the wiring.
    @Test("the General gates are handed the ownership")
    func gatesTakeTheOwnership() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/SettingsModel+AutoStart.swift"
            )
        let body = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(body.contains("guiManaged:guiManaged"))
    }

    /// `QuitLayoutStyle` has one case, so no behavioural test can
    /// tell a write from none: the verb's routing is pinned by
    /// shape instead, beside its sibling's.
    @Test("the quit verbs write the session value")
    func quitVerbsRouteThroughTheLedger() throws {
        let body = try squashed("Commands/KiwiCore+SettingsCommands.swift")
        for field in ["quitLayout=style", "quitGridTargetDepth=Int("] {
            #expect(
                body.contains("setAppWide(persisting:false){$0.\(field)"),
                "\(field) does not route through the session write"
            )
        }
    }
}
