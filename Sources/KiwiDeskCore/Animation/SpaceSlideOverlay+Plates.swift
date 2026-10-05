import AppKit

/// One page of the plate strip (#1956): each pile in a glass
/// container of its own, so overlapping glass reads as glass on
/// glass rather than as stacked slabs, and the page clipped to its
/// own screen-sized frame.
extension SpaceSlideOverlay {
    func pageView(
        _ plates: [SpaceSlidePlan.Plate],
        at offset: CGFloat,
        in current: Play
    ) -> NSView {
        let bounds = CGRect(origin: .zero, size: current.screen.size)
        let page = NSView(
            frame: CGRect(
                origin: Self.pageOrigin(offset, current.axis),
                size: bounds.size
            )
        )
        page.wantsLayer = true
        page.layer?.masksToBounds = true
        let piles = Dictionary(grouping: plates, by: \.pile)
        for pile in piles.keys.sorted() {
            let members = piles[pile] ?? []
            let views = members.map { plateView($0, in: current) }
            page.addSubview(pileView(views, bounds: bounds, current.glass))
        }
        return page
    }

    /// A pile's plates, back to front, in one glass container —
    /// or a plain view where the plates are material.
    private func pileView(
        _ views: [NSView],
        bounds: CGRect,
        _ glass: Bool
    ) -> NSView {
        let content = NSView(frame: bounds)
        for view in views { content.addSubview(view) }
        guard glass, let container = GlassPlate.makeContainer() else {
            return content
        }
        container.frame = bounds
        GlassPlate.setContainerContent(container, content)
        return container
    }

    /// One plate: Liquid Glass (`.regular`, the shortcuts panel's)
    /// or, where the gate stands glass down, the material the
    /// shortcuts panel falls back to — with the app icon centred
    /// on the part of the window the page shows, on a pile's front
    /// face only.
    private func plateView(
        _ plate: SpaceSlidePlan.Plate,
        in current: Play
    ) -> NSView {
        let rect = local(plate.frame, in: current)
        let content = NSView(frame: CGRect(origin: .zero, size: rect.size))
        if let pid = plate.iconPid,
            let side = SpaceSlidePlan.iconSide(on: rect),
            let image = icon(pid)
        {
            let view = NSImageView(
                frame: CGRect(
                    x: (rect.width - side) / 2,
                    y: (rect.height - side) / 2,
                    width: side,
                    height: side
                )
            )
            view.image = image
            view.imageScaling = .scaleProportionallyUpOrDown
            content.addSubview(view)
        }
        let radius = SpaceSlidePlan.cornerRadius
        if current.glass, let glass = GlassPlate.make(regular: true) {
            GlassPlate.update(glass, frame: rect, cornerRadius: radius)
            GlassPlate.setContent(glass, content)
            return glass
        }
        let material = NSVisualEffectView(frame: rect)
        material.material = .popover
        material.blendingMode = .behindWindow
        material.state = .active
        material.wantsLayer = true
        material.layer?.cornerRadius = radius
        material.layer?.masksToBounds = true
        material.addSubview(content)
        return material
    }
}
