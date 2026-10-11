import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Every Advanced Colours colour row resolves to the stored hex of
/// its own palette colour (#1857): writing through the lookup
/// moves exactly one palette path, and no two rows share one — so
/// a group colour writes the row the user ticked and nothing else.
@Suite("Advanced Colours hex lookup")
struct AdvancedColorPathsTests {
    @Test("each colour row writes its own palette colour")
    func eachRowWritesOnePaletteColour() throws {
        let keys = SettingKey.allCases.filter {
            $0.placement.area == .advancedColours
                && !ColorRole.paintKeys.contains($0)
        }
        #expect(keys.count == ColorPaletteKeys.all.count)
        let base = ColorPaletteKeys.extract(from: TilingSettings())
        var seen: Set<String> = []
        for key in keys {
            let path = try #require(
                AdvancedColorPaths.hex(key),
                "\(key.id) has no stored hex"
            )
            var settings = TilingSettings()
            settings[keyPath: path] = "#010203"
            let moved = ColorPaletteKeys.extract(from: settings)
                .filter { base[$0.key] != $0.value }
                .map(\.key)
            #expect(moved.count == 1, "\(key.id) moved \(moved)")
            if let only = moved.first {
                #expect(seen.insert(only).inserted, "\(key.id)")
            }
        }
        #expect(AdvancedColorPaths.hex(.kiwishelf(.border)) == nil)
    }
}
