import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A symbol name can be a `ComposedSymbol`'s `kiwi.*` name, which
/// `NSImage(systemSymbolName:)` answers with nil (#3284). So an AppKit
/// site building an image from a name it did not spell goes through
/// `SymbolImage.named`, and the sites that take only names they know
/// are plain symbols — a layout's, a Space's icon, a cue's own — are
/// the register below, with their counts. Scans both Sources trees.
///
/// Trades, stated: a spelled literal passes (it can never be
/// composed), so a constant naming a composed glyph through a
/// literal-free path is the residue; only the `systemSymbolName:`
/// spelling is scanned, so `NSImage(symbolName:)`, `NSImage(named:)`
/// handed a name, or a configuration chained on an image built
/// elsewhere pass it; SwiftUI's `Image(systemName:)` is not scanned
/// — its door is `GlyphImage`, review's to hold.
@Suite("Symbol names reach AppKit through SymbolImage (#3284)")
struct SymbolNameDoorTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let door = "KiwiDeskCore/Borders/SymbolImage.swift"

    /// Who may build from a name it did not spell, and how often.
    private static let allowed: [String: Int] = [
        // Fixed refusal and cue symbols, handed in as values.
        "KiwiDeskCore/Borders/SizeLimitPillPlate.swift": 1,
        "KiwiDeskCore/Bar/BarPeekBody+More.swift": 1,
        "KiwiDeskCore/Bar/FloatBreakMark.swift": 1,
        // The shelf handle's window and label symbols.
        "KiwiDeskCore/Bar/ShelfHandleSpec+Label.swift": 1,
        "KiwiDeskCore/Bar/ShelfHandleSpec+Count.swift": 1,
        "KiwiDeskCore/Bar/ShelfCountView.swift": 1,
        // A Space's icon, its marker or its layout's symbol: a user
        // icon reaches them only past `KiwiCore.iconIsSymbol`, which
        // refuses a composed name (`userIconsNeverCompose`).
        "KiwiDeskCore/App/KiwiCore+SpaceBarItems.swift": 1,
        "KiwiDeskCore/Bar/SpaceBarItemView+Marker.swift": 1,
        "KiwiDeskCore/Bar/SpaceBarItemView+Style.swift": 1,
        "KiwiDeskCore/Bar/SpaceBarItemView+Ends.swift": 1,
        "KiwiDesk/StatusItemController+SpaceMark.swift": 2,
        "KiwiDesk/StatusItemController+Icon.swift": 1,
    ]

    /// `systemSymbolName:` followed by anything but a string literal.
    private func unspelled(in flat: String) -> Int {
        let needle = "systemSymbolName:"
        var count = 0
        var rest = flat[...]
        while let hit = rest.range(of: needle) {
            if rest[hit.upperBound...].first != "\"" { count += 1 }
            rest = rest[hit.upperBound...]
        }
        return count
    }

    @Test("an unspelled symbol name reaches AppKit only through the door")
    func namesTakeTheDoor() throws {
        let tree = Self.root.appendingPathComponent("Sources")
        var found: [String: Int] = [:]
        for url in try SourceScan.swiftSources(under: tree) {
            let path = String(url.path.dropFirst(tree.path.count + 1))
            let flat = try SourceScan.strippedSource(at: url)
                .filter { !$0.isWhitespace }
            let count = unspelled(in: flat)
            if count > 0 { found[path] = count }
        }
        #expect(found[Self.door] != nil, "the needle stopped matching")
        found[Self.door] = nil
        #expect(found == Self.allowed)
    }

    @Test("a user icon spelling a composed name stays text")
    @MainActor
    func userIconsNeverCompose() {
        for symbol in ComposedSymbol.all {
            #expect(!KiwiCore.iconIsSymbol(symbol.name), "\(symbol.name)")
        }
    }

    @Test("no composed name is also a GUI custom glyph")
    @MainActor
    func registriesAreDisjoint() {
        for symbol in ComposedSymbol.all {
            #expect(symbol.name.hasPrefix(CustomGlyph.prefix))
            #expect(CustomGlyph(name: symbol.name) == nil, "\(symbol.name)")
        }
    }

    @Test("the SwiftUI composer places by Core's one layout")
    func swiftUIReadsTheLayout() throws {
        let url = Self.root.appendingPathComponent(
            "Sources/KiwiDesk/Shortcuts/ComposedSymbolView.swift"
        )
        let flat = try SourceScan.strippedSource(at: url)
            .filter { !$0.isWhitespace }
        let reads = flat.components(separatedBy: "symbol.layout(in:").count
        // The badge, the knockout and the frame each ask it, and the
        // frame is the layout's canvas.
        #expect(reads - 1 == 3)
        #expect(flat.contains(".canvas"))
        #expect(!flat.contains("scaleEffect"))
    }
}
