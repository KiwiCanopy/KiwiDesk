import Foundation
import Testing

/// A departure record ends through ONE door (#1387):
/// `StateCoordinator.retireDepartureRecord`, which promotes the
/// holder the record names before dropping it. A bare
/// `departedSlots[id] = nil` beside a call site is how an ender
/// skipped the promotion — `HandedBreakEnderTests` holds the
/// enders it knows, this holds the spelling for the one it does
/// not. The #634 reset (`departedSlots = [:]`) drops holder and
/// head together and is not matched; the re-key's `removeValue`
/// moves an entry rather than ending it and is the one such
/// spelling allowed.
@Suite("Departure record retire seam")
struct DepartedSlotRetireSeamTests {
    @Test("a record is dropped only inside the retire door")
    func onlyTheDoorDropsARecord() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let prefix = root.path + "/"
        // Every drop spelling on a dictionary.
        let pattern = try NSRegularExpression(
            pattern: #"departedSlots\[[^\]]+\]\s*=\s*nil"#
                + #"|departedSlots\.remove(Value|All)\("#
        )
        var hits: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let source = try SourceScan.strippedSource(at: file)
            let count = pattern.numberOfMatches(
                in: source,
                range: NSRange(source.startIndex..., in: source)
            )
            guard count > 0 else { continue }
            hits[String(file.path.dropFirst(prefix.count))] = count
        }
        #expect(
            hits == [
                "State/StateCoordinator+SpaceMemory.swift": 1,
                // `rekey` moves the entry to the fresh id.
                "State/StateCoordinator.swift": 1,
            ],
            "a record drop outside `retireDepartureRecord`: \(hits)"
        )
    }
}
