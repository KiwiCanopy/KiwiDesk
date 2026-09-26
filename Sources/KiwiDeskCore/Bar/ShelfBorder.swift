import AppKit

/// The shelf's border (#1679): one stroke painter every surface
/// it rims calls — the plate, each box under Boxed, the Space
/// Bar's front-app chip. The stroke is a fill-less layer's own
/// border, which CALayer draws inside the bounds flush with the
/// edge: on the plate's edge, never inset from it.
enum ShelfBorder {
    /// Paints `view` as the border of the surface whose frame it
    /// already holds: `KiwiShelf.drawnBorderWidth` in the shelf's
    /// border colour on `cornerRadius`, hidden where `shows` is
    /// false or the border is off.
    @MainActor
    static func paint(
        _ view: NSView,
        shelf: KiwiShelf,
        cornerRadius: CGFloat,
        shows: Bool = true
    ) {
        let width = shows ? shelf.drawnBorderWidth : 0
        view.wantsLayer = true
        view.isHidden = width == 0
        guard let layer = view.layer else { return }
        layer.backgroundColor = nil
        layer.borderWidth = width
        layer.borderColor =
            width > 0
            ? NSColor(kiwiHex: shelf.borderColor).cgColor : nil
        layer.cornerRadius = cornerRadius
    }

    /// A border view: layer-backed, fill-less, blind to the
    /// pointer so the surface beneath keeps its clicks.
    @MainActor
    static func make() -> NSView {
        let view = PassThroughView()
        view.wantsLayer = true
        view.isHidden = true
        return view
    }

    /// Hit-tests to nothing: a rim above an item must not take
    /// the item's clicks, hover or drag.
    final class PassThroughView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
