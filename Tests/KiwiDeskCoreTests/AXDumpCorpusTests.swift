import Foundation
import Testing

@testable import KiwiDeskCore

/// Real apps' recorded AX facts replayed through float and tile
/// detection (#1883): AeroSpace's MIT `axDumps/` corpus, vendored
/// under `AXDumps/`, against the table KiwiDesk keeps itself in
/// `AXDumpExpected`. Off the main actor: it reads about 125 small
/// files and touches no AppKit state.
///
/// The shell column is half a check: AeroSpace's dumper skips
/// `AXChildren`, so a window with no title-bar button is never
/// decidable and only `.furnished` rows say anything. A shadow
/// regression on a buttonless window goes unseen here
/// (`ShadowRuleTests` holds that rule on fixtures).
@Suite("AX dump corpus (#1883)")
struct AXDumpCorpusTests {
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("AXDumps")

    /// Every dump under `AXDumps/`, by its path there.
    static func corpus() throws -> [AXDump] {
        let base = directory.standardizedFileURL.path
        let walker = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil
        )
        var dumps: [AXDump] = []
        while let url = walker?.nextObject() as? URL {
            guard url.pathExtension == "json5" else { continue }
            let path = url.standardizedFileURL
                .deletingPathExtension().path
            dumps.append(
                try AXDump(
                    name: String(path.dropFirst(base.count + 1)),
                    data: Data(contentsOf: url)
                )
            )
        }
        return dumps.sorted { $0.name < $1.name }
    }

    @Test("every dump has exactly one row, and every row a dump")
    func oneRowPerDump() throws {
        let dumps = try Self.corpus().map(\.name)
        let rows = AXDumpExpected.all.map(\.name)
        #expect(dumps.count > 100, "the corpus read too little")
        #expect(Set(rows).count == rows.count, "a row is listed twice")
        #expect(Set(dumps) == Set(rows))
    }

    @Test("each dump's verdict is the frozen one")
    func verdictsHold() throws {
        let expected = Dictionary(
            AXDumpExpected.all.map { ($0.name, $0.verdict) },
            uniquingKeysWith: { first, _ in first }
        )
        for dump in try Self.corpus() {
            let row = try #require(expected[dump.name], "\(dump.name)")
            #expect(dump.verdict == row, "\(dump.name)")
        }
    }

    /// Non-vacuity: a loader that lost a fact would leave every
    /// row "not decidable" and still match a table frozen from it.
    /// Detection and admission only: the shell column cannot
    /// carry this (see the suite's docstring).
    @Test("most dumps decide detection and admission")
    func mostRowsDecide() throws {
        let dumps = try Self.corpus()
        let decided = dumps.filter {
            $0.verdict.detection != nil && $0.verdict.admission != nil
        }
        #expect(decided.count * 4 > dumps.count * 3)
        #expect(dumps.contains { $0.verdict.detection == .tiles })
        #expect(dumps.contains { $0.verdict.admission == .ignored })
    }

    /// AeroSpace's dumps carry its own classification beside the
    /// facts; the table is KiwiDesk's, so none of it is read.
    @Test("the loader reads facts, never AeroSpace's verdicts")
    func readsNoVerdict() throws {
        let facts: Set<String> = [
            "Aero.App.appBundleId",
            "Aero.App.nsApp.activationPolicy",
            "Aero.windowLevel",
            "Aero.AxFailed",
        ]
        let aero = AXDump.readKeys.filter { $0.hasPrefix("Aero.") }
        #expect(aero == facts)
        // The init applies the allowlist: a verdict key in the
        // file never reaches a reader.
        let dump = try AXDump(
            name: "probe",
            data: Data(#"{"AXRole": "w", "Aero.workspace": "1"}"#.utf8)
        )
        #expect(Set(dump.values.keys) == ["AXRole"])
        let here = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let verdictKeys = [
            "AxUiElementWindowType", "on-window-detected",
            "treeNodeParent", "Aero.workspace",
        ]
        // The loader, the table and its parts: every `AXDump*`
        // source but this suite, which names the keys it bans.
        let files = try FileManager.default
            .contentsOfDirectory(atPath: here.path)
            .filter {
                $0.hasPrefix("AXDump") && $0.hasSuffix(".swift")
                    && $0 != "AXDumpCorpusTests.swift"
            }
        #expect(files.count >= 5, "the scan found \(files)")
        for file in files {
            let source = try String(
                contentsOf: here.appendingPathComponent(file),
                encoding: .utf8
            )
            #expect(source.count > 500, "\(file) read empty")
            for key in verdictKeys {
                #expect(!source.contains(key), "\(file) reads \(key)")
            }
        }
    }

    @Test("the MIT notice and the pinned commit sit beside the data")
    func noticeBesideTheData() throws {
        let license = try String(
            contentsOf: Self.directory.appendingPathComponent(
                "LICENSE.txt"
            ),
            encoding: .utf8
        )
        #expect(license.hasPrefix("MIT License"))
        #expect(license.contains("Copyright (c) 2023 Nikita Bobko"))
        let upstream = try String(
            contentsOf: Self.directory.appendingPathComponent(
                "UPSTREAM.md"
            ),
            encoding: .utf8
        )
        #expect(
            upstream.contains("74a1bf17e82d70e0a21945ba04bb4f590bf19f83")
        )
    }
}
