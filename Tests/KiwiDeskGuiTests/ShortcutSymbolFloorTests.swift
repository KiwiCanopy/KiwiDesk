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

    private var glyphsFile: URL {
        Self.root.appendingPathComponent(
            "Sources/KiwiDesk/Shortcuts/ShortcutsReference+Glyphs.swift"
        )
    }

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
            try String(contentsOf: glyphsFile, encoding: .utf8)
        )
        let gates = source.matches(of: /#available\(macOS (\d+)/)
            .map { Int($0.1) }
        let since = ShortcutsReferenceBuilder.FloorSymbol.since
        #expect(gates == [since])
    }

    /// The check below finds a stand-in by its newer name, so a site
    /// reading `.name` draws it on the floor macOS and still passes:
    /// every read of a `FloorSymbol` outside its type is `.drawn`.
    @Test("a stand-in is read only through drawn")
    func standInsAreReadThroughDrawn() throws {
        let glyphs = SourceScan.stripComments(
            try String(contentsOf: glyphsFile, encoding: .utf8)
        )
        let names = glyphs.matches(of: /static let (\w+) = FloorSymbol\(/)
            .map { String($0.1) }
        #expect(
            names.count == ShortcutsReferenceBuilder.floorSymbols.count,
            "the declarations no longer read as `static let x = …`"
        )
        let tree = Self.root.appendingPathComponent("Sources/KiwiDesk")
        var reads = 0
        for file in try SourceScan.swiftSources(under: tree) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            for name in names {
                let member = try Regex<(Substring, Substring)>(
                    "\\b\(name)\\.(\\w+)"
                )
                for read in source.matches(of: member) {
                    reads += 1
                    #expect(
                        read.1 == "drawn",
                        "\(file.lastPathComponent) reads \(name).\(read.1)"
                    )
                }
            }
        }
        #expect(reads >= names.count, "no stand-in read found")
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
        // A stand-in wears no other row's glyph (#2529: reset sizing's
        // bare counterclockwise arrow).
        let floors = stand.map(\.floor)
        #expect(Set(floors).count == floors.count)
        #expect(Set(floors).isDisjoint(with: drawn))
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
