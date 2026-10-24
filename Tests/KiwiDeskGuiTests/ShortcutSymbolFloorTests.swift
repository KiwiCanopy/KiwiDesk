import Foundation
import Testing

@testable import KiwiDesk

/// Every symbol the Shortcuts side draws exists on the deployment
/// floor's macOS, or is a `FloorSymbol` whose stand-in does (#2529):
/// a newer name resolves on the host and CI, so only the OS's own
/// availability table sees a row the floor would draw bare. The
/// floor is read from `Package.swift`. Main-actor spend: one builder
/// census and one plist read.
@Suite("Shortcut symbols exist on the deployment floor")
@MainActor
struct ShortcutSymbolFloorTests {
    private static let table = URL(
        fileURLWithPath: "/System/Library/CoreServices/CoreGlyphs.bundle"
            + "/Contents/Resources/name_availability.plist"
    )

    private static let root = SourceScan.repoRoot(from: #filePath)

    /// The manifest's floor, read as `BuildStampTests` reads it in
    /// the Core target, which this one cannot see.
    private func floorMajor() throws -> Int {
        let manifest = try String(
            contentsOf: Self.root.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        let declared = try #require(
            manifest.firstMatch(of: /\.macOS\(\.v(\d+)\)/)?.1,
            "Package.swift declares no macOS deployment target"
        )
        return try #require(Int(declared))
    }

    /// The macOS major each symbol first shipped in, by name.
    private func firstMacOS() throws -> [String: Int] {
        let data = try Data(contentsOf: Self.table)
        let plist = try #require(
            try PropertyListSerialization.propertyList(
                from: data,
                format: nil
            ) as? [String: Any]
        )
        let symbols = try #require(plist["symbols"] as? [String: String])
        let years = try #require(
            plist["year_to_release"] as? [String: [String: String]]
        )
        return symbols.compactMapValues { year in
            years[year]?["macOS"]
                .flatMap { $0.split(separator: ".").first }
                .flatMap { Int($0) }
        }
    }

    /// `FloorSymbol.since` is what the check below trusts, and
    /// `#available` takes no variable, so the gate's literal is held
    /// to it by reading the source.
    @Test("the stand-in gate is the macOS the check trusts")
    func gateMatchesSince() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: Self.root.appendingPathComponent(
                    "Sources/KiwiDesk/Shortcuts/"
                        + "ShortcutsReference+Glyphs.swift"
                ),
                encoding: .utf8
            )
        )
        let gates = source.matches(of: /#available\(macOS (\d+)/)
            .map { Int($0.1) }
        let since = ShortcutsReferenceBuilder.FloorSymbol.since
        #expect(gates == [since])
    }

    @Test("every drawn symbol exists on the floor or has a stand-in")
    func symbolsExistOnTheFloor() throws {
        let floor = try floorMajor()
        let since = try firstMacOS()
        #expect(since.count > 1000, "the availability table read empty")
        let drawn = Set(
            ShortcutRowSymbolTests.drawable().compactMap(
                ShortcutsReferenceBuilder.icon(for:)
            )
                + ShortcutFold.Family.allCases.compactMap(
                    ShortcutsReferenceBuilder.foldIcon(for:)
                )
                + ShortcutsReferenceBuilder.verbSymbols
        )
        #expect(drawn.count > 20, "the census drew too few symbols")
        let stand = ShortcutsReferenceBuilder.floorSymbols
        for symbol in drawn {
            let first = try #require(since[symbol], "\(symbol) unlisted")
            if let pair = stand.first(where: { $0.name == symbol }) {
                let gate = ShortcutsReferenceBuilder.FloorSymbol.since
                #expect(first <= gate, "\(symbol) needs \(first)")
                let back = try #require(since[pair.floor])
                #expect(back <= floor, "\(pair.floor) needs \(back)")
            } else {
                #expect(first <= floor, "\(symbol) needs macOS \(first)")
            }
        }
    }
}
