import AppKit

/// The shelf's views, made once (#1517): the plates, the tint and
/// the panel the strip draws in.
extension ShelfOverlay {
    /// The solid plate, made once.
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

    func tintView() -> GlassBackdrop {
        if let glassTint { return glassTint }
        let tint = GlassBackdrop()
        glassTint = tint
        return tint
    }

    func makePanel() -> NSPanel {
        let panel = BarPanel.configure(
            ShelfPanel(
                contentRect: .zero,
                styleMask: BarPanel.styleMask,
                backing: .buffered,
                defer: true
            )
        )
        panel.onPress = { [weak self] in self?.onPress($0) }
        content.wantsLayer = true
        content.layer?.masksToBounds = true
        panel.contentView = content
        stripView.wantsLayer = true
        content.addSubview(stripView)
        content.addSubview(
            plateBorder,
            positioned: .below,
            relativeTo: stripView
        )
        divider.wantsLayer = true
        divider.isHidden = true
        stripView.addSubview(divider)
        handle.isHidden = true
        handle.onHover = { [weak self] in self?.setDividerHovered($0) }
        stripView.addSubview(handle)
        return panel
    }
}
