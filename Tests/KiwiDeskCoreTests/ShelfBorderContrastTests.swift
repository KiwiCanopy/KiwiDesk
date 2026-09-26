import Foundation
import Testing

@testable import KiwiDeskCore

/// Every bundled palette's border colour reads (#1679, #1684): a
/// border earns its keep where the plate's own edge is weakest, so
/// it is measured against the palette's HOME wallpaper — the
/// extreme its composited plate contrasts least with — and never
/// against the plate, which it rims rather than sits on.
@Suite("Shelf border contrast")
struct ShelfBorderContrastTests {
    /// The idle-ink and ring floor (`IdleItemContrastTests`).
    private static let floor = 2.2
    private static let wallpapers = ["#FFFFFF", "#000000"]

    /// The wallpaper extreme the plate blends into: its composite
    /// over each, and the one it stands out from least.
    static func home(fill: String) -> String? {
        let measured = wallpapers.compactMap { wall -> (String, Double)? in
            guard let plate = ColorVision.composite(fill, over: wall),
                let contrast = ColorVision.contrast(plate, wall)
            else { return nil }
            return (wall, contrast)
        }
        guard measured.count == wallpapers.count else { return nil }
        return measured.min { $0.1 < $1.1 }?.0
    }

    @Test("A dark plate's home is black, a light one's white")
    func homeFollowsThePlate() {
        #expect(Self.home(fill: "#14201CB3") == "#000000")
        #expect(Self.home(fill: "#F2F2F7B3") == "#FFFFFF")
    }

    @Test("Every bundled palette's border clears the floor at home")
    func bordersReadAtHome() throws {
        #expect(!PaletteCatalog.bundled().isEmpty)
        var measured = 0
        for palette in PaletteCatalog.bundled() {
            let name = Comment(rawValue: palette.name)
            let border = try #require(
                palette.colors["kiwishelf.border_color"],
                name
            )
            let fill = try #require(
                palette.colors["kiwishelf.fill_color"],
                name
            )
            let home = try #require(Self.home(fill: fill), name)
            let drawn = try #require(
                ColorVision.composite(border, over: home),
                name
            )
            let contrast = try #require(
                ColorVision.contrast(drawn, home),
                name
            )
            #expect(
                contrast >= Self.floor,
                Comment(
                    rawValue: "\(palette.name) on \(home): \(contrast)"
                )
            )
            measured += 1
        }
        #expect(measured == PaletteCatalog.bundled().count)
    }
}
