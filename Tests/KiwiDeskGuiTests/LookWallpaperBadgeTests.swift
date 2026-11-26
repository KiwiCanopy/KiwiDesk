import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The saved tiles' wallpaper badge (#3478): visible at rest on a
/// saved tile and never on a bundled one, its glyph naming the
/// state, its items the row menu's own. Main actor: the statics it
/// reads live on views, and a scan of two files is its whole spend.
@Suite("Look wallpaper badge")
@MainActor
struct LookWallpaperBadgeTests {
    static let a = String(repeating: "a", count: 64) + ".png"
    static let b = String(repeating: "b", count: 64) + ".png"

    @Test("the badge's items are the row menu's wallpaper items")
    func itemsAreTheRowMenus() {
        #expect(
            LooksShelf.wallpaperMenu == [
                .colours(.lookChooseWallpaper),
                .colours(.lookUseCurrentWallpaper),
                .colours(.lookRemoveWallpaper),
            ]
        )
        let menu = ColorsRowOrder.looksContextMenu
        let places = LooksShelf.wallpaperMenu.compactMap {
            menu.firstIndex(of: $0)
        }
        #expect(places == places.sorted())
    }

    @Test("the glyph's shape names none, one or a picture per screen")
    func glyphNamesTheState() {
        typealias Badge = LookWallpaperBadge<EmptyView>
        let symbols = [
            Badge.symbol(for: nil),
            Badge.symbol(for: .all(Self.a)),
            Badge.symbol(for: .perScreen([1: Self.a, 2: Self.b])),
        ]
        #expect(Set(symbols).count == 3)
        #expect(symbols[0] == "photo.badge.plus")
    }

    /// The badge rides the saved group's cards alone, and the tile
    /// draws it outside its button, whose label takes no clicks for
    /// a menu inside it.
    @Test("only a saved tile mounts the badge, over its button")
    func savedTilesMountIt() throws {
        let dir = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Looks"
            )
        let shelf = try SourceScan.strippedSource(
            at: dir.appendingPathComponent("LooksShelf.swift")
        ).filter { !$0.isWhitespace }
        let bundled = try #require(shelf.range(of: "varbundledGroup"))
        let user = try #require(shelf.range(of: "varuserGroup"))
        let badge = "badge:AnyView(wallpaperBadge(look))"
        let mounts = shelf.ranges(of: badge)
        #expect(mounts.count == 1)
        #expect(mounts.allSatisfy { $0.lowerBound > user.lowerBound })
        #expect(
            !shelf[bundled.lowerBound..<user.lowerBound].contains(badge)
        )
        let tile = try SourceScan.strippedSource(
            at: dir.appendingPathComponent("LookTile.swift")
        ).filter { !$0.isWhitespace }
        let button = try #require(tile.range(of: "Button(action:apply)"))
        let overlay = try #require(
            tile.range(of: ".overlay(alignment:.topTrailing){badge?")
        )
        let style = try #require(tile.range(of: ".buttonStyle(.plain)"))
        #expect(button.lowerBound < style.lowerBound)
        #expect(style.lowerBound < overlay.lowerBound)
    }
}
