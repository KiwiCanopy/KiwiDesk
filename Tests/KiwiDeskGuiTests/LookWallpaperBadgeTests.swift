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
        // The saved group's body alone: `card(` both groups call sits
        // after it, so a mount moved there reds.
        let user = try #require(shelf.range(of: "varuserGroup"))
        let end = try #require(
            shelf.range(
                of: "privatefuncgroupHeader",
                range: user.upperBound..<shelf.endIndex
            )
        )
        // Any spelling of the mount, and `card(` hands its badge on
        // unchanged, so no default there reaches a bundled tile.
        let badge = "wallpaperBadge("
        #expect(shelf.ranges(of: badge).count == 1)
        #expect(shelf[user.upperBound..<end.lowerBound].contains(badge))
        #expect(shelf.contains("badge:badge,"))
        let tile = try SourceScan.strippedSource(
            at: dir.appendingPathComponent("LookTile.swift")
        ).filter { !$0.isWhitespace }
        let button = try #require(tile.range(of: "Button(action:apply)"))
        let overlay = try #require(
            tile.range(of: ".overlay(alignment:.topTrailing){letrisen")
        )
        let style = try #require(tile.range(of: ".buttonStyle(.plain)"))
        #expect(button.lowerBound < style.lowerBound)
        #expect(style.lowerBound < overlay.lowerBound)
        #expect(
            tile[overlay.upperBound...].hasPrefix(
                "=pointerOver&&isEnabled&&!appliedbadge?"
            )
        )
    }

    /// The drawing reads the state: the badge's glyph is its own
    /// wallpaper's, and its menu draws every item of the list.
    @Test("the badge draws its state and every item")
    func badgeDrawsItsState() throws {
        let dir = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Looks"
            )
        let view = try SourceScan.strippedSource(
            at: dir.appendingPathComponent("LookWallpaperBadge.swift")
        ).filter { !$0.isWhitespace }
        #expect(view.contains("Image(systemName:symbol)"))
        #expect(
            view.contains(
                "privatevarsymbol:String{Self.symbol(for:wallpaper)}"
            )
        )
        let shelf = try SourceScan.strippedSource(
            at: dir.appendingPathComponent("LooksShelf+Badge.swift")
        ).filter { !$0.isWhitespace }
        #expect(
            shelf.contains(
                "ForEach(Self.wallpaperMenu,id:\\.id){keyin"
                    + "menuItem(key,look,divides:false)"
            )
        )
    }
}
