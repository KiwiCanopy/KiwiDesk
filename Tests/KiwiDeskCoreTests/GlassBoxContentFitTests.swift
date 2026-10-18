import AppKit
import Testing

@testable import KiwiDeskCore

/// A box glass's hosted content — a Space chip — follows the glass
/// to every size the box takes: left to the glass's own layout, a
/// chip kept its old length inside a resized box (#2425, device).
@Suite("Glass content fit", .serialized)
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

    /// A glass no box hosts — the hover peek's, the sticky mark's —
    /// resizes through `GlassPlate.update`, which fits its content.
    @Test("An unhosted glass's update fits its content")
    func updateFitsTheContent() throws {
        guard #available(macOS 26, *) else { return }
        let glass = try #require(GlassPlate.make())
        let content = NSView()
        GlassPlate.setContent(glass, content)
        GlassPlate.update(
            glass,
            frame: CGRect(x: 0, y: 0, width: 200, height: 120),
            cornerRadius: 8
        )
        glass.layoutSubtreeIfNeeded()
        GlassPlate.update(
            glass,
            frame: CGRect(x: 0, y: 0, width: 200, height: 260),
            cornerRadius: 8
        )
        #expect(content.frame == glass.bounds)
    }

    /// The device state: the box already has its size, so the
    /// place's own `GlassPlate.update` heals the chip.
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
