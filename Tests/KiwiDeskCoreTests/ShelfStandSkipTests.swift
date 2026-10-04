import AppKit
import Testing

@testable import KiwiDeskCore

/// **A shelf show that moves no section stands nothing** (#1942).
/// The stand's flush is a synchronous layout pass of every bar
/// view, so a glide whose sections all keep their slots — a Space
/// switch on a settled shelf — skips it; a joining section or a
/// start off its frame still stands (#1838).
@Suite("Shelf stand skip (#1942)")
@MainActor
struct ShelfStandSkipTests {
    private static let strip = CGRect(x: 0, y: 0, width: 1000, height: 40)

    private static func section(
        _ view: NSView,
        slot: CGRect = strip,
        content: CGRect = CGRect(x: 10, y: 0, width: 600, height: 40)
    ) -> ShelfOverlay.Section {
        .init(
            view: view,
            slot: slot,
            plate: CGRect(origin: .zero, size: slot.size),
            content: content
        )
    }

    private static func shown(_ section: ShelfOverlay.Section) -> ShelfOverlay
    {
        var shelf = KiwiShelf()
        shelf.liquidGlass = false
        let overlay = ShelfOverlay()
        overlay.show(
            strip: strip,
            edge: .top,
            shelf: shelf,
            sheen: 0,
            sections: [section]
        )
        return overlay
    }

    @Test("A section on its slot stands nothing")
    func unchangedSlotSkips() {
        let view = NSView()
        let overlay = Self.shown(Self.section(view))
        let again = Self.section(
            view,
            content: CGRect(x: 10, y: 0, width: 500, height: 40)
        )
        #expect(
            overlay.standWrites([again], in: Self.strip, horizontal: true)
                .isEmpty
        )
        #expect(
            !overlay.standGlideStarts(
                [again],
                in: Self.strip,
                horizontal: true
            )
        )
    }

    @Test("A joining section stands")
    func joiningStands() {
        let overlay = Self.shown(Self.section(NSView()))
        let joining = Self.section(
            NSView(),
            slot: CGRect(x: 600, y: 0, width: 400, height: 40)
        )
        #expect(
            overlay.standWrites([joining], in: Self.strip, horizontal: true)
                .map(\.1).first.map {
                    if case .join = $0 { true } else { false }
                } == true
        )
    }

    @Test("A moved slot whose content shifts inside it stands")
    func movedSlotStands() {
        let view = NSView()
        let overlay = Self.shown(Self.section(view))
        let moved = Self.section(
            view,
            slot: CGRect(x: 100, y: 0, width: 900, height: 40),
            content: CGRect(x: 4, y: 0, width: 600, height: 40)
        )
        #expect(
            overlay.standWrites([moved], in: Self.strip, horizontal: true)
                .count == 1
        )
        #expect(
            overlay.standGlideStarts([moved], in: Self.strip, horizontal: true)
        )
    }
}
