import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A new setup splits the bars: Space Bar on top, App Bar on the
/// bottom (#1528 item 14). Measured on the composed profile — the
/// first-run seed's and every preset apply's door — not on
/// `StarterTuning.base()`, which a caller could stop reaching.
@Suite("Starter setups seed the App Bar on the bottom (#1528)")
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

    @Test("every preset splits the bars too")
    func presetsSplit() throws {
        for preset in StandardProfiles.workflows {
            for size in [laptop, ultrawide] {
                let sizes = Array(
                    repeating: size,
                    count: max(1, preset.screenCount)
                )
                let edges = try composedEdges(preset, on: sizes)
                #expect(edges.space == .top, "\(preset.name) \(size)")
                #expect(edges.app == .bottom, "\(preset.name) \(size)")
            }
            // Screens unknown: no shape tuning, the base alone.
            let blind = preset.settings(sizes: nil)
            #expect(blind.appBarStyle.edge == .bottom, "\(preset.name)")
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
}
