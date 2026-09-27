import AppKit

/// The shelf's border (#1679): one stroke painter every surface
/// it rims calls — the plate, each box under Boxed, the Space
/// Bar's front-app chip. The stroke is a fill-less layer's own
/// border, which CALayer draws inside the bounds flush with the
/// edge: on the plate's edge, never inset from it.
enum ShelfBorder {
    /// What a rim sits on. Which of the two the shelf rims is
    /// decided here, from `KiwiShelf.drawsPlate`, never by a caller.
    enum Surface {
        /// The one plate under Plain.
        case plate
        /// An item's box, or the front-app chip, under Boxed.
        case box
    }

    /// Whether `shelf` rims `surface` at all: the plate while it
    /// draws one, a box while it draws boxes instead.
    static func rims(_ surface: Surface, on shelf: KiwiShelf) -> Bool {
        switch surface {
        case .plate: return shelf.drawsPlate
        case .box: return !shelf.drawsPlate
        }
    }

    /// Paints `view` as the border of the `surface` whose frame it
    /// already holds: `KiwiShelf.drawnBorderWidth` in the shelf's
    /// border colour on `cornerRadius`, hidden where the shelf
    /// does not rim that surface or the border is off. With `sheen`
    /// (#1644) the rim draws its ramp in place of the layer's flat
    /// stroke.
    @MainActor
    static func paint(
        _ view: NSView,
        shelf: KiwiShelf,
        surface: Surface,
        cornerRadius: CGFloat,
        sheen: Bool
    ) {
        let width =
            rims(surface, on: shelf) ? shelf.drawnBorderWidth : 0
        view.wantsLayer = true
        view.isHidden = width == 0
        guard let layer = view.layer else { return }
        let ramp = sheen && width > 0
        layer.backgroundColor = nil
        layer.borderWidth = ramp ? 0 : width
        layer.borderColor =
            width > 0
            ? NSColor(kiwiHex: shelf.borderColor).cgColor : nil
        layer.cornerRadius = cornerRadius
        (view as? SheenRimView)?.paint =
            ramp
            ? SheenRimView.Paint(
                hex: shelf.borderColor,
                width: width,
                grounds: BorderSheen.grounds(plate: shelf.fillColor)
            )
            : nil
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
    final class PassThroughView: SheenRimView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
