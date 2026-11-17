import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The tour's Spaces list fades its edge for Current alone (#3375):
/// every layout it offers fits about four rows on a screen, so an
/// offered option's column never runs past the list.
@Suite("Offered layouts fit the tour's list (#3375)", .serialized)
@MainActor
struct TourPlanRowsTests {
    /// The rows the list shows in German, the longest catalog,
    /// measured on the tour window (#3375).
    private static let rowsShown = 4

    private func makeCore(_ sizes: [CGSize]) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-rows-\(UUID().uuidString)")
        )
        var x: CGFloat = 0
        for (index, size) in sizes.enumerated() {
            core.state.workspaces.upsertDisplay(
                Display(
                    id: DisplayID(UInt32(index + 1)),
                    name: "Screen \(index + 1)",
                    frame: CGRect(origin: CGPoint(x: x, y: 0), size: size)
                )
            )
            x += size.width
        }
        return core
    }

    @Test("every offered layout's column fits the list", arguments: 1...5)
    func columnsFit(screens: Int) {
        let shapes: [CGSize] = [
            CGSize(width: 1512, height: 982),
            CGSize(width: 2560, height: 1440),
            CGSize(width: 3440, height: 1440),
            CGSize(width: 5120, height: 1440),
        ]
        for shape in shapes {
            let sizes = Array(repeating: shape, count: screens)
            let core = makeCore(sizes)
            let offered = StandardProfiles.layouts(for: screens, sizes: sizes)
            for layout in offered {
                let plan = core.tourPlan(for: layout)
                let tallest = plan.map(\.spaces.count).max() ?? 0
                #expect(
                    tallest <= Self.rowsShown,
                    "\(layout.name), \(screens) × \(shape): \(tallest)"
                )
            }
        }
    }
}
