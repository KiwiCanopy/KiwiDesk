import AppKit
import Testing

@testable import KiwiDeskCore

/// A `GlassBox` glass has one frame writer, its host's
/// `setFrameSize` (#2878 ▸ Ruling): the glass is minted with no
/// autoresizing mask, a `place` writes no glass frame, and every
/// size the host takes lays the glass to its bounds exactly.
@Suite("Glass box frame ownership (#2878)", .serialized)
@MainActor
struct GlassBoxOwnershipTests {
    private func box() throws -> (glass: NSView, tint: GlassBackdrop)? {
        guard #available(macOS 26, *) else { return nil }
        let parent = NSView(
            frame: CGRect(x: 0, y: 0, width: 400, height: 40)
        )
        return try #require(GlassBox.make(in: parent))
    }

    private func place(
        _ box: (glass: NSView, tint: GlassBackdrop),
        at frame: CGRect,
        animated: Bool,
        move: @escaping BarFrameMove = { view, frame, _ in
            view.frame = frame
        }
    ) {
        GlassBox.place(
            box.glass,
            tint: box.tint,
            at: frame,
            cornerRadius: 8,
            fill: GlassFill(hex: "#202020B3"),
            edge: .top,
            visible: true,
            animated: animated,
            move: move
        )
    }

    @Test("a minted glass carries no autoresizing mask")
    func mintedWithoutMask() throws {
        guard let box = try box() else { return }
        #expect(box.glass.autoresizingMask.isEmpty)
    }

    @Test(
        "a place lays the glass to its host, animated or not",
        arguments: [true, false]
    )
    func placeFillsTheHost(animated: Bool) throws {
        guard let box = try box() else { return }
        let host = try #require(GlassBox.host(of: box.glass))
        place(
            box,
            at: CGRect(x: 10, y: 0, width: 63, height: 30),
            animated: false
        )
        place(
            box,
            at: CGRect(x: 10, y: 0, width: 107.7, height: 30),
            animated: animated
        )
        #expect(host.frame.width == 107.7)
        #expect(box.glass.frame == host.bounds)
    }

    @Test("a direct host write lays the glass to its bounds")
    func hostWriteFillsTheGlass() throws {
        guard let box = try box() else { return }
        let host = try #require(GlassBox.host(of: box.glass))
        host.frame = CGRect(x: 0, y: 0, width: 81.3, height: 28)
        #expect(box.glass.frame == host.bounds)
        host.frame = CGRect(x: 4, y: 0, width: 40, height: 28)
        #expect(box.glass.frame == host.bounds)
    }

    /// The proof that `place` writes no frame: with a move that
    /// leaves the host alone, an offset glass stays where it was.
    @Test("a place writes no glass frame of its own")
    func placeWritesNoFrame() throws {
        guard let box = try box() else { return }
        let frame = CGRect(x: 10, y: 0, width: 63, height: 30)
        place(box, at: frame, animated: false)
        let offset = CGRect(x: 3, y: 2, width: 50, height: 20)
        box.glass.frame = offset
        for animated in [false, true] {
            place(
                box,
                at: frame.offsetBy(dx: 20, dy: 0),
                animated: animated,
                move: { _, _, _ in }
            )
        }
        #expect(box.glass.frame == offset)
    }

    /// The host heals a glass left off its bounds at its next frame
    /// write, a same-size move included.
    @Test("a same-size host move lays a stray glass back")
    func sameSizeMoveHeals() throws {
        guard let box = try box() else { return }
        let frame = CGRect(x: 10, y: 0, width: 63, height: 30)
        place(box, at: frame, animated: false)
        box.glass.frame = CGRect(x: 3, y: 2, width: 50, height: 20)
        place(box, at: frame.offsetBy(dx: 20, dy: 0), animated: false)
        let host = try #require(GlassBox.host(of: box.glass))
        #expect(box.glass.frame == host.bounds)
    }
}
