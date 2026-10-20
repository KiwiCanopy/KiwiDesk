import Foundation
import Testing

/// The Hyper remap's ownership record (#1870) is written by
/// `HyperKeyRemap` alone, and minted only by `apply`'s set and the
/// user's take-over (#2471): a writer anywhere else could claim a
/// mapping by its shape, which the Hammerspoon case forbids.
@Suite("Hyper remap record has one writer")
struct HyperRemapRecordWriterCensusTests {
    @Test("only HyperKeyRemap writes the ownership record")
    func oneWriterHome() throws {
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
            let hits =
                text.components(separatedBy: "writeWritten(").count - 1
            if hits > 0 { writers[path] = hits }
        }
        #expect(
            Set(writers.keys) == [
                "OS/HyperKeyRemap.swift",
                "OS/HyperKeyRemap+Claim.swift",
            ],
            "\(writers)"
        )
        // A new write in either home is a review question, so
        // both counts are pinned (#2471).
        #expect(writers["OS/HyperKeyRemap.swift"] == 6, "\(writers)")
        #expect(writers["OS/HyperKeyRemap+Claim.swift"] == 1)
    }

    /// A writer can skip `writeWritten(` and store the record
    /// itself; the record's builder and its defaults key each keep
    /// one home.
    @Test("the record is built and stored in one place")
    func recordHasOneStore() throws {
        let core = scriptFixtureRepoRoot()
            .appendingPathComponent("Sources/KiwiDeskCore")
        let files = try #require(
            FileManager.default.enumerator(atPath: core.path)
        )
        var builds: [String: Int] = [:]
        var keys: [String: Int] = [:]
        for case let path as String in files
        where path.hasSuffix(".swift") {
            let text = try String(
                contentsOf: core.appendingPathComponent(path),
                encoding: .utf8
            )
            let b =
                text.components(separatedBy: "HyperKeyRemap.record(")
                .count - 1
            let k =
                text.components(separatedBy: "HyperKeyRemapWritten")
                .count - 1
            if b > 0 { builds[path] = b }
            if k > 0 { keys[path] = k }
        }
        #expect(keys == ["OS/HyperKeyRemap.swift": 1], "\(keys)")
        #expect(builds == ["OS/HyperKeyRemap.swift": 1], "\(builds)")
    }
}
