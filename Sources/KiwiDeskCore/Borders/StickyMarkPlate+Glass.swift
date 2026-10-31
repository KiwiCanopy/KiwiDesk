import AppKit

/// The window mark as frosted Liquid Glass (#1621, #2831): the
/// glyphs ride inside the glass, each in its state's colour, and the
/// untinted glass follows the app's appearance. The plate's own
/// clip carries the corner shape, pill morph included.
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
            if let glass { GlassPlate.release(glass) }
            glass?.isHidden = true
            hud.isHidden = false
            content.frame = bounds
            addSubview(content, positioned: .above, relativeTo: hud)
        }
        setMarkColor(markHex)
    }

    /// Untinted glass, the glyphs each in their own colour (#2831):
    /// a state's colour is its symbol's, never the glass's.
    func applyGlass() {
        guard let glass else { return }
        Self.paint(symbol, hex: markHex)
        Self.paint(innerSymbol, hex: slotCount > 1 ? innerHex : "")
        name.textColor = markColor
        GlassPlate.update(glass, frame: bounds, cornerRadius: 0)
        GlassTint.apply(
            tint,
            in: glass,
            cornerRadius: 0,
            fill: GlassFill(hex: ""),
            edge: .top
        )
    }

    /// The glass, hosted once beneath the glyphs; nil below 26.
    private func glassView() -> NSView? {
        if let glass { return glass }
        // Frosted, so the untinted glass reads light over any
        // window rather than a grey film (owner, #2831).
        guard let made = GlassPlate.make(regular: true) else {
            return nil
        }
        made.frame = bounds
        made.autoresizingMask = [.width, .height]
        addSubview(made, positioned: .above, relativeTo: hud)
        glass = made
        return made
    }
}
