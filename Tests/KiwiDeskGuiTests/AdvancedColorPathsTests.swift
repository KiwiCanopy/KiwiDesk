import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Every Colors & glass colour row resolves to the stored hex of
/// its own palette colour (#1857): writing through the lookup
/// moves exactly one palette path, and that path is the one the
/// row's census id names — so a group colour writes the row the
/// user ticked, never its neighbour.
@Suite("Colors & glass hex lookup")
struct AdvancedColorPathsTests {
    /// The census id's group, spelled as the palette spells it.
    private static let groups: [String: String] = [
        "kiwishelf": "kiwishelf",
        "spaceBarStyle": "space_bar",
        "borderStyle": "border",
        "dragGhost": "drag.ghost",
        "dragDropZone": "drag.drop_zone",
        "stickyStyle": "sticky",
        "floatingStyle": "floating",
    ]

    /// `settings.kiwishelf.activeItemColor` →
    /// `kiwishelf.active_item_color`, derived from the id rather
    /// than listed, so the expectation is not a second copy of
    /// the lookup.
    private static func palettePath(of key: SettingKey) -> String? {
        let parts = key.id.split(separator: ".").map(String.init)
        guard parts.count == 3, parts[0] == "settings",
            let group = groups[parts[1]]
        else { return nil }
        let leaf = parts[2].reduce(into: "") { out, c in
            if c.isUppercase {
                out += "_" + c.lowercased()
            } else {
                out.append(c)
            }
        }
        return "\(group).\(leaf)"
    }

    /// The path a sentinel write through the lookup moves.
    private static func moved(by key: SettingKey) -> [String] {
        guard let path = AdvancedColorPaths.hex(key) else { return [] }
        let base = ColorPaletteKeys.extract(from: TilingSettings())
        var settings = TilingSettings()
        settings[keyPath: path] = "#010203"
        return ColorPaletteKeys.extract(from: settings)
            .filter { base[$0.key] != $0.value }
            .map(\.key)
    }

    private var colourKeys: [SettingKey] {
        SettingKey.allCases.filter {
            $0.isColourRow
                && SettingsDraftDiff.namesModelPath($0.id)
        }
    }

    @Test("each colour row writes the palette colour its id names")
    func eachRowWritesItsOwnPaletteColour() throws {
        #expect(colourKeys.count == ColorPaletteKeys.all.count)
        for key in colourKeys {
            let expected = try #require(
                Self.palettePath(of: key),
                "\(key.id) does not name a palette colour"
            )
            #expect(
                Self.moved(by: key) == [expected],
                "\(key.id) writes \(Self.moved(by: key))"
            )
        }
        #expect(AdvancedColorPaths.hex(.kiwishelf(.border)) == nil)
    }

    /// The rows a group colour never ticks are exactly the ones
    /// Core's `ColorPaletteKeys.followers` lets follow another
    /// colour (#1856) — a second follower joins the groups' list
    /// or reds here, never gets painted over its pairing.
    @Test("each group's followers are Core's")
    func followersAreCores() {
        for role in ColorRole.allCases {
            for key in role.keys {
                let path = Self.moved(by: key).first ?? ""
                #expect(
                    role.followers.contains(key)
                        == (ColorPaletteKeys.followers[path] != nil),
                    "\(key.id) in \(role)"
                )
            }
        }
    }
}
