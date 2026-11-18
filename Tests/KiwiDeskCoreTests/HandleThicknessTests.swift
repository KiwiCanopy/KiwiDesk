import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `kiwishelf.handle_thickness` (#3451): how deep an Auto bar's
/// handle and the Pocket's tab draw, whole points in 2–6, a look
/// style path; clamped at decode and set, and absent reading 3.
@Suite("KiwiShelf handle thickness (#3451)")
@MainActor
struct HandleThicknessTests {
    @Test("An absent field reads the shipped 3 pt")
    func absentReadsTheDefault() throws {
        let shelf = try JSONDecoder().decode(
            KiwiShelf.self,
            from: Data("{}".utf8)
        )
        #expect(shelf.handleThickness == 3)
        #expect(ShelfHandleSpec.depth(of: shelf) == 3)
    }

    @Test(
        "Decode clamps to whole points in the range",
        arguments: [(0.5, 2.0), (40.0, 6.0), (3.6, 4.0), (5.0, 5.0)]
    )
    func decodeClamps(stored: Double, drawn: Double) throws {
        let json = #"{"handle_thickness": \#(stored)}"#
        let shelf = try JSONDecoder().decode(
            KiwiShelf.self,
            from: Data(json.utf8)
        )
        #expect(shelf.handleThickness == CGFloat(drawn))
    }

    @Test(
        "The setter clamps to whole points in the range",
        arguments: [(-3.0, 2.0), (1.0, 2.0), (9.0, 6.0), (4.4, 4.0)]
    )
    func setterClamps(value: Double, stored: Double) throws {
        let setting = try KiwiShelfCommandSetting.parse(
            field: "handle_thickness",
            args: [.number(value)]
        ).get()
        var shelf = KiwiShelf()
        setting.apply(to: &shelf)
        #expect(shelf.handleThickness == CGFloat(stored))
    }

    /// A writer that skips the clamp still draws inside the range.
    @Test("The handle and the Pocket's tab read the clamped depth")
    func depthIsResolved() {
        var shelf = KiwiShelf()
        shelf.handleThickness = 40
        #expect(ShelfHandleSpec.depth(of: shelf) == 6)
        #expect(PocketHandleView.tabDepth(of: shelf) == 6)
        shelf.handleThickness = 4
        #expect(
            PocketHandleView.restDepth(holds: false, of: shelf)
                == 4 + PocketHandleView.lookOut(holds: false)
        )
    }

    @Test("A look carries it, and every bundled look names it")
    func looksCarryIt() {
        #expect(LookKeys.styling.contains("kiwishelf.handle_thickness"))
        let screen = CGSize(width: 1512, height: 982)
        let looks = LookCatalog.bundled(sizes: [screen])
        let picks: [String: Double] = [
            "Glass": 3, "Classic": 2, "Tiler": 2, "Pill": 3,
            "Taskbar": 4, "Sakura": 3,
        ]
        for look in looks {
            let value = look.style["kiwishelf.handle_thickness"]
            #expect(
                value == .number(picks[look.name] ?? -1),
                "\(look.name): \(String(describing: value))"
            )
        }
        #expect(Set(looks.map(\.name)) == Set(picks.keys))
    }

    @Test("The bar handle's frame takes the shelf's depth")
    func barHandleFrameReadsTheShelf() {
        let run = CGRect(x: 100, y: 0, width: 400, height: 30)
        let frame = ShelfHandleSpec.frame(
            along: run,
            edge: .bottom,
            side: 900,
            depth: 5
        )
        #expect(frame.height == 5)
        #expect(frame.maxY == 900)
    }
}
