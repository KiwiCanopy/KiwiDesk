import Foundation
import Testing

/// The Space Bar's two drop doors ask the Space move's own
/// refusal (#3119), held by spelling: no fixture drives a drag of
/// a native full-screen window onto a bar item.
@Suite("Space Bar drops ask the Space move refusal (#3119)")
struct SpaceMoveDoorSeamTests {
    /// The relocate drop asks the refusal, which cues, before the
    /// move; the move's own net would refuse in silence.
    @Test("the relocate drop asks before it moves")
    func relocateAsks() throws {
        let body = try SourceScan.functionBody(
            of: "handleDragEnd",
            in: "KiwiCore+Drag.swift",
            under: "Tiling"
        )
        let ask = body.range(of: "if spaceMoveRefusal(id) == nil {")
        let move = body.range(of: "moveWindow(id, to: target")
        #expect(ask != nil)
        #expect(move != nil)
        if let ask, let move, ask.lowerBound < move.lowerBound {
            // Inside the branch: no brace closes it before the move.
            let between = body[ask.upperBound..<move.lowerBound]
            #expect(!between.contains("}"))
        } else {
            Issue.record("the move precedes its ask")
        }
    }

    /// The spring files past `moveWindow`, so it asks ahead of its
    /// sticky arm, as the verb does, and of the filing.
    @Test("the spring asks ahead of its sticky arm")
    func springAsks() throws {
        let body = try SourceScan.functionBody(
            of: "springSwitchSpace",
            in: "KiwiCore+SpaceBarDrop.swift",
            under: "Bar"
        )
        let ask = body.range(
            of: "if spaceMoveRefusal(window) != nil { return false }"
        )
        let sticky = body.range(of: "stickyMoveRefused(window")
        let file = body.range(of: "fileMembership(window")
        #expect(ask != nil)
        #expect(sticky != nil)
        #expect(file != nil)
        if let ask, let sticky, let file {
            #expect(ask.lowerBound < sticky.lowerBound)
            #expect(ask.lowerBound < file.lowerBound)
        }
    }
}
