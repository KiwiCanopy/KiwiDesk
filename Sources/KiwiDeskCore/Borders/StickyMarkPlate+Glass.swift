import AppKit

/// The sticky mark as tinted Liquid Glass (#1621): the colour tints
/// the glass through `GlassTint`, fading downward, instead of
/// filling a disc, and the glyphs ride inside the glass so they
/// take the dark variant `GlassTint` pins from a dark colour, the
/// app's appearance otherwise (#1308). The
/// plate's own clip carries the corner shape, pill morph included.
extension StickyMarkPlate {
    /// Switches between the `.hudWindow` badge and glass; the
    /// glyphs move host only when the mode changes (#1315). A
    /// steady state repaints nothing: `setMarkColor`, which every
    /// sync calls next, applies the tint.
    func setGlass(_ on: Bool) {
        let plate = on ? glassView() : nil
        let glassNow = plate != nil
        guard glassNow != isGlass else { return }
        isGlass = glassNow
        if let plate {
            hud.isHidden = true
            plate.isHidden = false
            GlassPlate.setContent(plate, content)
        } else {
            if let glass { GlassPlate.detach(glass) }
            glass?.isHidden = true
            tint.isHidden = true
            hud.isHidden = false
            content.frame = bounds
            addSubview(content, positioned: .above, relativeTo: hud)
        }
        setMarkColor(markHex)
    }

    /// Tints the glass with the stored colour; the glyphs take the
    /// label ink the pinned variant resolves.
    func applyGlass() {
        guard let glass else { return }
        roundel.isHidden = true
        markColor = .labelColor
        symbol.contentTintColor = .labelColor
        name.textColor = .labelColor
        GlassPlate.update(glass, frame: bounds, cornerRadius: 0)
        GlassTint.apply(
            tint,
            below: glass,
            frame: bounds,
            cornerRadius: 0,
            hex: markHex,
            edge: .top
        )
    }

    /// The glass, hosted once beneath the glyphs; nil below 26.
    private func glassView() -> NSView? {
        if let glass { return glass }
        guard let made = GlassPlate.make() else { return nil }
        made.frame = bounds
        made.autoresizingMask = [.width, .height]
        addSubview(made, positioned: .above, relativeTo: hud)
        glass = made
        return made
    }
}
