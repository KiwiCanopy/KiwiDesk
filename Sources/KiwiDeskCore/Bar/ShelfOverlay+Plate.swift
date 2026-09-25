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
        BarMotion.setFrame(divider, to: frame, animated: animated)
        divider.layer?.backgroundColor =
            BarDivider.sectionColor(textColor: shelf.itemColor).cgColor
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
        let ordered = slots.sorted {
            horizontal ? $0.minX < $1.minX : $0.minY < $1.minY
        }
        let middle =
            horizontal
            ? (ordered[0].maxX + ordered[1].minX) / 2 - strip.minX
            : (ordered[0].maxY + ordered[1].minY) / 2 - strip.minY
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
