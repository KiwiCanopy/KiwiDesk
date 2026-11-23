import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// KiwiHub's size per side (#3570 ▸ Ruling): a fixed 720 pt field
/// row, Windows and View at most 720 × 488, Desktops and Shortcuts
/// as wide as their content up to 96 pt from each side and as tall
/// as 48 pt above the area's bottom, never lifted. Pure arithmetic
/// over the rect handed in, a screen's or a screen area's.
@Suite("KiwiHub room")
struct JumpPanelRoomTests {
    private typealias Room = JumpPanelRoom
    private let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)

    private func room(_ area: CGRect? = nil) -> Room {
        Room(visible: visible, area: area ?? visible, topFraction: 0.25)
    }

    @Test("the field row is 720 pt, narrowed only by a narrow area")
    func fieldRow() {
        #expect(room().fieldWidth == 720)
        let narrow = room(CGRect(x: 0, y: 0, width: 600, height: 900))
        #expect(narrow.fieldWidth == 520)
    }

    @Test("Windows and View keep the field row's width")
    func compactWidth() {
        for scope in [JumpScope.windows, .view] {
            #expect(Room.sizing(of: scope) == .compact)
        }
        #expect(room().width(.compact, content: 2000) == 720)
    }

    @Test("Desktops and Shortcuts take their content's width, clamped")
    func growingWidth() {
        for scope in [JumpScope.desktops, .shortcuts] {
            #expect(Room.sizing(of: scope) == .grows)
        }
        let room = room()
        #expect(room.width(.grows, content: 0) == 720)
        #expect(room.width(.grows, content: 1000) == 1000)
        #expect(room.width(.grows, content: 5000) == CGFloat(1440 - 192))
        // A narrow area never takes a growing side under the field.
        let narrow = Room(
            visible: visible,
            area: CGRect(x: 0, y: 0, width: 800, height: 900),
            topFraction: 0.25
        )
        #expect(narrow.width(.grows, content: 5000) == 720)
    }

    @Test("each side's height: 488 compact, else to 48 pt above")
    func heights() {
        let room = room()
        #expect(room.top == 675)
        #expect(room.height(.compact) == 488)
        #expect(room.height(.grows) == CGFloat(675 - 48))
        // A shelf raising the area's bottom shortens a growing side.
        let raised = self.room(CGRect(x: 0, y: 100, width: 1440, height: 800))
        #expect(raised.height(.grows) == CGFloat(675 - 100 - 48))
        // A short screen fits a compact side 40 pt above its bottom.
        let short = Room(
            visible: CGRect(x: 0, y: 0, width: 1440, height: 500),
            area: CGRect(x: 0, y: 0, width: 1440, height: 500),
            topFraction: 0.25
        )
        #expect(short.height(.compact) == CGFloat(375 - 40))
    }

    /// The field sits at the same line on every side: the origin
    /// takes the top, never a lift, and a refit holds the centre.
    @Test("the panel stands centred under its top, never lifted")
    func originAndRefit() {
        let area = CGRect(x: 1440, y: 0, width: 1000, height: 900)
        let room = Room(visible: area, area: area, topFraction: 0.25)
        let origin = room.origin(of: CGSize(width: 720, height: 800))
        #expect(origin.x == CGFloat(1940 - 360))
        #expect(origin.y == room.top - 800)
        let frame = CGRect(
            origin: origin,
            size: CGSize(width: 720, height: 800)
        )
        let wide = Room.refitted(frame, to: CGSize(width: 900, height: 300))
        #expect(wide.midX == frame.midX)
        #expect(wide.maxY == frame.maxY)
        #expect(wide.size == CGSize(width: 900, height: 300))
    }
}
