import AppKit
import Testing

@testable import KiwiDeskCore

/// A box glass's hosted content — a Space chip — follows the glass
/// to every size the box takes: left to the glass's own layout, a
/// chip kept its old length inside a resized box (#2425, device).
@Suite("Glass box content fit", .serialized)
@MainActor
struct GlassBoxContentFitTests {
    private func hostedBox(
        at frame: CGRect
    ) throws -> (glass: NSView, tint: GlassBackdrop, content: NSView)? {
        guard #available(macOS 26, *) else { return nil }
        let parent = NSView(
            frame: CGRect(x: 0, y: 0, width: 400, height: 40)
        )
        let box = try #require(GlassBox.make(in: parent))
        let content = NSView()
        GlassPlate.setContent(box.glass, content)
        place(box.glass, box.tint, at: frame)
        box.glass.layoutSubtreeIfNeeded()
        return (box.glass, box.tint, content)
    }

    private func place(
        _ glass: NSView,
        _ tint: GlassBackdrop,
        at frame: CGRect
    ) {
        GlassBox.place(
            glass,
            tint: tint,
            at: frame,
            cornerRadius: 8,
            hex: "#202020B3",
            edge: .top,
            visible: true,
            animated: true,
            move: { view, frame, _ in view.frame = frame }
        )
    }

    @Test("A resized box writes its content to the glass's size")
    func resizeFitsTheContent() throws {
        guard
            let box = try hostedBox(
                at: CGRect(x: 10, y: 0, width: 63, height: 30)
            )
        else { return }
        place(
            box.glass,
            box.tint,
            at: CGRect(x: 10, y: 0, width: 107, height: 30)
        )
        #expect(box.content.frame.size == box.glass.bounds.size)
        place(
            box.glass,
            box.tint,
            at: CGRect(x: 80, y: 0, width: 63, height: 30)
        )
        #expect(box.content.frame.size == box.glass.bounds.size)
    }

    /// The device state: the box already has its size. AppKit still
    /// runs the host's `setFrameSize` on the place's unchanged
    /// frame, so the next full render heals the chip.
    @Test("A place heals content stranded at an old size")
    func placeHealsStaleContent() throws {
        guard
            let box = try hostedBox(
                at: CGRect(x: 10, y: 0, width: 107, height: 30)
            )
        else { return }
        box.content.frame = CGRect(x: 0, y: 0, width: 63, height: 30)
        place(
            box.glass,
            box.tint,
            at: CGRect(x: 10, y: 0, width: 107, height: 30)
        )
        #expect(box.content.frame == box.glass.bounds)
    }
}
