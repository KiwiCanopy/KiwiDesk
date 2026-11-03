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

    /// The proof that `place` writes no frame: a host that keeps its
    /// size takes no write, so an offset glass stays where it was.
    @Test("a place whose host keeps its size leaves the glass alone")
    func placeWritesNoFrame() throws {
        guard let box = try box() else { return }
        let frame = CGRect(x: 10, y: 0, width: 63, height: 30)
        place(box, at: frame, animated: false)
        let offset = CGRect(x: 3, y: 2, width: 50, height: 20)
        box.glass.frame = offset
        place(box, at: frame.offsetBy(dx: 20, dy: 0), animated: true)
        #expect(box.glass.frame == offset)
    }
}
