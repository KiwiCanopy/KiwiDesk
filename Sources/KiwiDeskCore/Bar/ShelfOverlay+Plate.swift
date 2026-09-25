import AppKit

/// The shelf's one plate and the divider on it (#1517).
extension ShelfOverlay {
    /// Draws the plate at `frame` — glass with its tint where the
    /// shelf draws glass, else a solid fill — or none.
    func layoutPlate(
        _ frame: CGRect?,
        shelf: KiwiShelf,
        radius: CGFloat,
        animated: Bool
    ) {
        guard let frame else {
            hidePlates()
            return
        }
        if shelf.glassEnabled, let glass = glassPlateView() {
            solidPlateView().isHidden = true
            if glass.superview !== content {
                content.addSubview(
                    glass,
                    positioned: .below,
                    relativeTo: stripView
                )
            }
            glass.isHidden = false
            GlassPlate.setContent(glass, glassFiller)
            GlassPlate.update(
                glass,
                frame: frame,
                cornerRadius: radius,
                animated: animated
            )
            GlassTint.apply(
                tintView(),
                below: glass,
                frame: frame,
                cornerRadius: radius,
                hex: shelf.fillColor,
                edge: shelf.edge,
                animated: animated
            )
            return
        }
        glassPlate?.isHidden = true
        glassTint?.isHidden = true
        let plate = solidPlateView()
        if plate.superview !== content {
            content.addSubview(
                plate,
                positioned: .below,
                relativeTo: stripView
            )
        }
        plate.isHidden = false
        BarMotion.setFrame(plate, to: frame, animated: animated)
        plate.layer?.cornerRadius = radius
        plate.layer?.backgroundColor =
            NSColor(kiwiHex: shelf.fillColor).cgColor
    }

    /// A thin line between the two sections, in the item colour
    /// at the divider's fixed alpha — only while both show.
    func layoutDivider(
        sections: [Section],
        strip: CGRect,
        shelf: KiwiShelf,
        horizontal: Bool,
        animated: Bool
    ) {
        guard
            let frame = Self.dividerFrame(
                slots: sections.map(\.slot),
                strip: strip,
                horizontal: horizontal
            )
        else {
            divider.isHidden = true
            return
        }
        divider.isHidden = false
        dividerShelf = shelf
        BarMotion.setFrame(divider, to: frame, animated: animated)
        paintDivider()
    }

    /// The draggable divider under the pointer (#1517): the same
    /// line in the hover ink — the resize cursor carries the rest
    /// (owner 2026-09-25); instant, so Reduce Motion has nothing
    /// to gate.
    func setDividerHovered(_ hovered: Bool) {
        guard dividerHovered != hovered else { return }
        dividerHovered = hovered
        paintDivider()
    }

    private func paintDivider() {
        guard let shelf = dividerShelf else { return }
        divider.layer?.backgroundColor =
            (dividerHovered
            ? BarDivider.sectionHoverColor(hoverColor: shelf.hoverItemColor)
            : BarDivider.sectionColor(textColor: shelf.itemColor)).cgColor
    }

    /// The divider's frame in strip coordinates: centred in the
    /// gutter between two slots, `BarDivider.sectionLengthShare` of
    /// the depth long
    /// and a section break thick. Never full depth: a full-height
    /// seam splits the one plate back into two bars. Nil unless
    /// exactly two sections show.
    nonisolated static func dividerFrame(
        slots: [CGRect],
        strip: CGRect,
        horizontal: Bool
    ) -> CGRect? {
        guard slots.count == 2 else { return nil }
        let ranges = slots.map { slot in
            horizontal
                ? (slot.minX - strip.minX)...(slot.maxX - strip.minX)
                : (slot.minY - strip.minY)...(slot.maxY - strip.minY)
        }
        let middle = ShelfArrangement.gutterMiddle(ranges[0], ranges[1])
        return BarDivider.sectionFrame(
            at: middle,
            depth: horizontal ? strip.height : strip.width,
            horizontal: horizontal
        )
    }

    private func hidePlates() {
        solidPlate?.isHidden = true
        glassPlate?.isHidden = true
        glassTint?.isHidden = true
    }
}
