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

    /// The glass plate, minted once with its tint in a host of
    /// their own beneath the rim, which the plate glide moves
    /// (#2095). Nil below macOS 26, where there is no glass to draw.
    func glassPlateView() -> NSView? {
        if let glassPlate { return glassPlate }
        guard let box = GlassBox.make(in: content, below: plateBorder)
        else { return nil }
        glassPlate = box.glass
        glassTint = box.tint
        return box.glass
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
        panel.onPress = { [weak self] in self?.onPress($0, $1) }
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
