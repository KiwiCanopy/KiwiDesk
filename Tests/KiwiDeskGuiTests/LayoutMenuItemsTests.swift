import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// One Layout menu item list (#2777 ruling 16, amended 2026-10-31):
/// the Spaces page's pop-up and Simple's picture-faced menu draw the
/// same items, each with its layout's symbol, so the list is built in
/// one place and a second copy cannot drift from it. Reads the
/// source; no main actor.
@Suite("Layout menu items have one home")
struct LayoutMenuItemsTests {
    @Test("the item list draws each layout's symbol")
    func oneItemList() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let menu = try SourceScan.swiftSources(under: root)
            .first { $0.lastPathComponent == "SpaceModeMenu.swift" }
        let source = try SourceScan.strippedSource(at: try #require(menu))
            .filter { !$0.isWhitespace }
        #expect(
            source.contains(
                "Label(mode.displayName,systemImage:mode.symbol)"
            )
        )
        #expect(!source.contains("Image(nsImage:"))
    }

    /// A list of every layout drawn anywhere else is a second item
    /// list, one that can drift from the menu's. Each other site
    /// states its reason.
    /// Trades: a list built by `.map` over `allCases` is unseen.
    @Test("no second list of every layout")
    func noSecondLayoutList() throws {
        let allowed = [
            "SpaceModeMenu.swift": 1,
            // A frozen readout of a Space no profile declares; it
            // chooses nothing (#1790).
            "LiveOnlySpaceRow.swift": 1,
        ]
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var sites: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let count = try SourceScan.strippedSource(at: file)
                .filter { !$0.isWhitespace }
                .occurrences(of: "ForEach(LayoutMode.allCases")
            if count > 0 { sites[file.lastPathComponent] = count }
        }
        #expect(sites == allowed)
    }

    /// Floating's single window reads as an empty screen on a card,
    /// so its picture draws the whole scatter.
    @Test("Floating's picture draws its scatter")
    func floatingDrawsItsScatter() {
        // From a count below the scatter, so the floor is what
        // answers, not the default count.
        #expect(SimpleSpacePicture.windows(for: .floating, base: 1) >= 3)
        #expect(SimpleSpacePicture.windows(for: .floating) >= 3)
        #expect(
            SimpleSpacePicture.windows(for: .bsp)
                == LayoutSchematic.windowCount(
                    LayoutSchematic.defaultWindowCount,
                    for: .bsp
                )
        )
    }
}
