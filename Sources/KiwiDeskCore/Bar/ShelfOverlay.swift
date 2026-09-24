import AppKit

/// One display's shelf (#1517): the ONE panel both sections draw
/// on, the ONE plate beneath them — solid, or Liquid Glass with
/// its tint — and the divider between them. The sections render
/// into their own views (`SpaceBarOverlay.root`,
/// `AppBarOverlay.root`); this places them and owns the surface
/// they share, so there is one fill and no seam.
@MainActor
final class ShelfOverlay {
    /// A section to place: its view, its slot on the shelf in AX
    /// coordinates, and the plate its run asks for in the view's
    /// own coordinates.
    struct Section {
        let view: NSView
        let slot: CGRect
        let plate: CGRect
    }

    private(set) var panel: NSPanel?
    let content = AppBarOverlay.FlippedView()
    /// Holds both sections and the divider, above the plate.
    let stripView = AppBarOverlay.FlippedView()
    var solidPlate: NSView?
    var glassPlate: NSView?
    var glassTint: NSView?
    /// The glass shows through behind the sections rather than
    /// hosting them, so nothing is ever reparented into it.
    let glassFiller = NSView()
    let divider = NSView()

    var isVisible: Bool { panel?.isVisible == true }

    /// Lays the shelf out over `strip` (AX coordinates) with
    /// `shelf` as rendered — glass already gated by
    /// `LiquidGlassGate` — and shows it.
    func show(
        strip: CGRect,
        shelf: KiwiShelf,
        sections: [Section]
    ) {
        guard !sections.isEmpty, strip.width >= 1, strip.height >= 1
        else {
            hide()
            return
        }
        let panel = self.panel ?? makePanel()
        self.panel = panel
        // A shelf appearing arrives; one already on screen glides
        // to its new placement (#1517).
        let glides = panel.isVisible
        stripView.frame = CGRect(origin: .zero, size: strip.size)
        let horizontal = shelf.edge.isHorizontal
        let depth = horizontal ? strip.height : strip.width
        let plate = Self.plateFrame(
            sections: sections,
            strip: strip,
            shelf: shelf
        )
        BarMotion.runPlateGlide {
            place(sections, in: strip, animated: glides)
            layoutPlate(
                plate,
                shelf: shelf,
                radius: shelf.resolvedCornerRadius(forThickness: depth),
                animated: glides
            )
            layoutDivider(
                sections: sections,
                strip: strip,
                shelf: shelf,
                horizontal: horizontal,
                animated: glides
            )
        }
        panel.setFrame(
            GeometryUtils.flip(
                strip,
                primaryHeight: GeometryUtils.primaryHeight
            ),
            display: true
        )
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    func hide() {
        panel?.orderOut(nil)
    }

    /// The one plate under both sections, in strip coordinates:
    /// none while every item draws its own box, the whole strip
    /// under Full, else the union of what each section's run
    /// asks for — one joined plate.
    nonisolated static func plateFrame(
        sections: [Section],
        strip: CGRect,
        shelf: KiwiShelf
    ) -> CGRect? {
        guard shelf.drawsPlate else { return nil }
        let bounds = CGRect(origin: .zero, size: strip.size)
        guard !shelf.plateSpans else { return bounds }
        let asks = sections.compactMap { section -> CGRect? in
            guard !section.plate.isEmpty else { return nil }
            return section.plate.offsetBy(
                dx: section.slot.minX - strip.minX,
                dy: section.slot.minY - strip.minY
            )
        }
        guard let first = asks.first else { return nil }
        return asks.dropFirst().reduce(first) { $0.union($1) }
    }

    /// Adds each section's view once and sets its origin; a view
    /// no section names any more leaves the strip.
    private func place(
        _ sections: [Section],
        in strip: CGRect,
        animated: Bool
    ) {
        let wanted = sections.map(\.view)
        for view in stripView.subviews
        where view !== divider && !wanted.contains(where: { $0 === view }) {
            view.removeFromSuperview()
        }
        for section in sections {
            // A section joining lands at its slot; only one already
            // on the strip glides there (ruling 7).
            let joining = section.view.superview !== stripView
            if joining {
                stripView.addSubview(
                    section.view,
                    positioned: .below,
                    relativeTo: divider
                )
            }
            // Origin and size in ONE write, so a section never
            // re-lays at a new size from its old place.
            let frame = CGRect(
                x: section.slot.minX - strip.minX,
                y: section.slot.minY - strip.minY,
                width: section.slot.width,
                height: section.slot.height
            )
            BarMotion.setFrame(
                section.view,
                to: frame,
                animated: animated && !joining
            )
        }
    }

    func solidPlateView() -> NSView {
        if let solidPlate { return solidPlate }
        let plate = NSView()
        plate.wantsLayer = true
        solidPlate = plate
        return plate
    }

    /// Nil below macOS 26, where there is no glass to draw.
    func glassPlateView() -> NSView? {
        if let glassPlate { return glassPlate }
        glassPlate = GlassPlate.make()
        return glassPlate
    }

    func tintView() -> NSView {
        if let glassTint { return glassTint }
        let tint = NSView()
        glassTint = tint
        return tint
    }

    private func makePanel() -> NSPanel {
        let panel = BarPanel.makeNonActivating()
        content.wantsLayer = true
        content.layer?.masksToBounds = true
        panel.contentView = content
        stripView.wantsLayer = true
        content.addSubview(stripView)
        divider.wantsLayer = true
        divider.isHidden = true
        stripView.addSubview(divider)
        return panel
    }
}
