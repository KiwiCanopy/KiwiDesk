import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// One Layout menu item list (#2777 ruling 16): the Spaces page's
/// pop-up and Simple's picture-faced menu draw the same items, each
/// with its layout's picture, so the list is built in one place and
/// a second copy cannot drift from it. Reads the source; no main
/// actor.
@Suite("Layout menu items have one home")
struct LayoutMenuItemsTests {
    @Test("layout pictures are drawn into one item list")
    func oneItemList() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let files = try SourceScan.swiftSources(under: root)
        #expect(!files.isEmpty)
        var sites: [String: Int] = [:]
        for file in files {
            let count = try SourceScan.strippedSource(at: file)
                .occurrences(of: "LayoutMenuPictures.image(")
            if count > 0 { sites[file.lastPathComponent] = count }
        }
        #expect(sites == ["SpaceModeMenu.swift": 1])
    }

    /// A list of every layout drawn anywhere else is a second item
    /// list: one drawing `mode.symbol` beside the name copies the
    /// menu without its pictures. Each other site states its reason.
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

    /// Floating's single window reads as an empty screen at menu
    /// size, so its picture draws the whole scatter.
    @Test("Floating's picture draws its scatter")
    func floatingDrawsItsScatter() {
        // From a count below the scatter, so the floor is what
        // answers, not the default count.
        #expect(LayoutMenuPictures.windows(for: .floating, base: 1) >= 3)
        #expect(LayoutMenuPictures.windows(for: .floating) >= 3)
        #expect(
            LayoutMenuPictures.windows(for: .bsp)
                == LayoutSchematic.windowCount(
                    LayoutSchematic.defaultWindowCount,
                    for: .bsp
                )
        )
    }
}
