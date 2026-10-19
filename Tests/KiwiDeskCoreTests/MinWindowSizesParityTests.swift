import Foundation
import Testing

@testable import KiwiDeskCore

/// `MinWindowSizes` holds one floor per layout that applies one
/// (#2237): its stored fields, its `Layout` cases and
/// `LayoutMode` without Monocle are one list, read by reflection
/// so a layout added to `LayoutMode` reds here until it is given
/// a floor or joins `exempt` with its reason.
@Suite("Minimum window size parity")
struct MinWindowSizesParityTests {
    /// Layout → why it keeps no floor.
    private static let exempt: [LayoutMode: String] = [
        .monocle: "shows one window at a time and tiles none"
    ]

    @Test("every layout but the exempt keeps a floor")
    func layoutsMatchTheModes() {
        let modes = Set(
            LayoutMode.allCases.filter { Self.exempt[$0] == nil }
                .map(\.rawValue)
        )
        let layouts = Set(MinWindowSizes.Layout.allCases.map(\.rawValue))
        #expect(!layouts.isEmpty)
        #expect(layouts == modes)
        for mode in Self.exempt.keys {
            #expect(MinWindowSizes.Layout(mode) == nil)
        }
    }

    @Test("every layout has a stored field of its own")
    func fieldsMatchTheLayouts() {
        let fields = Set(
            Mirror(reflecting: MinWindowSizes()).children
                .compactMap(\.label)
        )
        #expect(
            fields == Set(MinWindowSizes.Layout.allCases.map(\.rawValue))
        )
    }

    /// The subscript reads and writes the field it names: setting
    /// one layout moves that layout's floor alone.
    @Test("the subscript reaches each layout's own field")
    func subscriptIsOneToOne() {
        for layout in MinWindowSizes.Layout.allCases {
            var sizes = MinWindowSizes()
            sizes[layout] = MinSize(width: 123, height: 45)
            for other in MinWindowSizes.Layout.allCases {
                let expected: MinSize =
                    other == layout
                    ? MinSize(width: 123, height: 45) : 300
                #expect(sizes[other] == expected, "\(layout)→\(other)")
            }
            let settings = TilingSettings()
            var edited = settings
            edited.minWindowSizes = sizes
            #expect(
                edited.minWindowSize(for: layout.mode, in: nil)
                    == MinSize(width: 123, height: 45)
            )
        }
    }

    @Test("Monocle resolves no floor")
    func monocleHasNone() {
        #expect(
            TilingSettings().minWindowSize(for: .monocle, in: nil)
                == .square(0)
        )
    }
}
