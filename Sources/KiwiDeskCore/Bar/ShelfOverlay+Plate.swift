import AppKit

/// The shelf's one plate and the divider on it (#1517).
extension ShelfOverlay {
    /// Draws the plate at `frame` — glass with its tint where the
    /// shelf draws glass, else a solid fill — or none.
    func layoutPlate(
        _ frame: CGRect?,
        shelf: KiwiShelf,
        radius: CGFloat
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
            GlassPlate.update(glass, frame: frame, cornerRadius: radius)
            GlassTint.apply(
                tintView(),
                below: glass,
                frame: frame,
                cornerRadius: radius,
                hex: shelf.fillColor
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
        plate.frame = frame
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
        horizontal: Bool
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
        divider.frame = frame
        divider.layer?.backgroundColor =
            BarDivider.color(textColor: shelf.itemColor).cgColor
    }

    /// The divider's frame in strip coordinates: centred in the
    /// gutter between two slots, half the depth long. Nil unless
    /// exactly two sections show.
    nonisolated static func dividerFrame(
        slots: [CGRect],
        strip: CGRect,
        horizontal: Bool
    ) -> CGRect? {
        guard slots.count == 2 else { return nil }
        let ordered = slots.sorted {
            horizontal ? $0.minX < $1.minX : $0.minY < $1.minY
        }
        let depth = horizontal ? strip.height : strip.width
        let length = depth / 2
        let inset = (depth - length) / 2
        if horizontal {
            let x = (ordered[0].maxX + ordered[1].minX) / 2 - strip.minX
            return CGRect(x: x - 0.5, y: inset, width: 1, height: length)
        }
        let y = (ordered[0].maxY + ordered[1].minY) / 2 - strip.minY
        return CGRect(x: inset, y: y - 0.5, width: length, height: 1)
    }

    private func hidePlates() {
        solidPlate?.isHidden = true
        glassPlate?.isHidden = true
        glassTint?.isHidden = true
    }
}
