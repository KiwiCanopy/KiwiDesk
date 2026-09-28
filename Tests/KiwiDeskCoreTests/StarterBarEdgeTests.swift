import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The starter splits the bars — Space Bar on top, App Bar on the
/// bottom — and nothing else does (#1528 item 14). Measured on the
/// composed profile, the first-run seed's and a preset apply's
/// door, never on a tuning helper a caller could stop reaching.
@Suite("The starter seeds the App Bar on the bottom (#1528)")
struct StarterBarEdgeTests {
    private let laptop = CGSize(width: 1728, height: 1117)
    private let ultrawide = CGSize(width: 3440, height: 1440)

    private func displays(_ sizes: [CGSize]) -> [Display] {
        var x: CGFloat = 0
        return sizes.enumerated().map { index, size in
            defer { x += size.width }
            return Display(
                id: DisplayID(UInt32(index + 1)),
                name: "S\(index + 1)",
                frame: CGRect(origin: CGPoint(x: x, y: 0), size: size)
            )
        }
    }

    private func composedEdges(
        _ layout: StandardLayout,
        on sizes: [CGSize]
    ) throws -> (space: AppBarEdge, app: AppBarEdge) {
        let composed = try #require(
            ProfileComposition.compose(
                layout: layout,
                displays: displays(sizes),
                mainID: DisplayID(1)
            )
        )
        return (
            composed.settings.spaceBarStyle.edge,
            composed.settings.appBarStyle.edge
        )
    }

    @Test("the starter splits the bars on every screen set")
    func starterSplits() throws {
        for sizes in [[laptop], [ultrawide], [laptop, ultrawide]] {
            let starter = StarterSetup.standardLayout(sizes: sizes)
            let edges = try composedEdges(starter, on: sizes)
            #expect(edges.space == .top, "\(sizes)")
            #expect(edges.app == .bottom, "\(sizes)")
        }
    }

    /// A preset apply and the monitor-change fallback replace the
    /// live settings whole, so a preset seeding the split would
    /// move an existing user's App Bar unasked.
    @Test("a preset keeps both bars on top")
    func presetsKeepTop() throws {
        for preset in StandardProfiles.workflows {
            for size in [laptop, ultrawide] {
                let sizes = Array(
                    repeating: size,
                    count: max(1, preset.screenCount)
                )
                let edges = try composedEdges(preset, on: sizes)
                #expect(edges.app == .top, "\(preset.name) \(size)")
            }
            // Screens unknown: no shape tuning, the base alone.
            let blind = preset.settings(sizes: nil)
            #expect(blind.appBarStyle.edge == .top, "\(preset.name)")
        }
        // The fallback a monitor change off the starter takes.
        for count in 1...2 {
            let fallback = try #require(
                ProfileComposition.compose(
                    displays: displays(
                        Array(repeating: laptop, count: count)
                    ),
                    mainID: DisplayID(1)
                )
            )
            #expect(fallback.settings.appBarStyle.edge == .top)
        }
    }

    /// The type default is what a stored profile without an edge
    /// decodes to; moving it would move existing setups' bars
    /// without the crossing #1369 demands.
    @Test("the type default stays top, so no profile moves")
    func typeDefaultUnchanged() {
        #expect(AppBarStyle().edge == .top)
        #expect(TilingSettings().appBarStyle.edge == .top)
    }

    @Test("a stored App Bar with no edge still loads on top")
    func storedWithoutEdgeLoadsTop() throws {
        let decoded = try JSONDecoder().decode(
            AppBarStyle.self,
            from: Data(#"{"title_cap": 12}"#.utf8)
        )
        #expect(decoded.edge == .top)
    }
}
