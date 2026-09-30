import AppKit

/// Placing the sections on the strip (#1517, #1838). A section
/// joining lands at its slot and fades in on the plate glide; one
/// already on the strip glides there from where its content was
/// DRAWN: the section re-lays its content for the new slot at once,
/// so a glide from its old frame would jump that content aside and
/// slide it back (#1838, measured on device).
extension ShelfOverlay {
    func place(
        _ sections: [Section],
        in strip: CGRect,
        horizontal: Bool,
        animated: Bool
    ) {
        let wanted = sections.map(\.view)
        for view in stripView.subviews
        where view !== divider && view !== handle
            && !wanted.contains(where: { $0 === view })
        {
            view.removeFromSuperview()
        }
        placedContent = placedContent.filter { key, _ in
            wanted.contains { ObjectIdentifier($0) == key }
        }
        for section in sections {
            let key = ObjectIdentifier(section.view)
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
            if animated, !joining, let drawn = placedContent[key] {
                section.view.frame = Self.glideStart(
                    from: section.view.frame,
                    drawn: drawn,
                    content: section.content,
                    to: frame,
                    horizontal: horizontal
                )
            }
            BarMotion.setFrame(
                section.view,
                to: frame,
                animated: animated && !joining
            )
            if joining, animated { section.view.alphaValue = 0 }
            BarMotion.setAlpha(section.view, to: 1, animated: animated)
            placedContent[key] = section.content
        }
    }

    /// Where a gliding section starts: at its new size, placed so
    /// its content — `content`, re-laid for the new slot — sits
    /// where it was drawn last (`drawn` in the section's `from`
    /// frame). A zero content reading glides from `from` as before.
    nonisolated static func glideStart(
        from: CGRect,
        drawn: CGRect,
        content: CGRect,
        to frame: CGRect,
        horizontal: Bool
    ) -> CGRect {
        guard drawn != .zero, content != .zero else { return from }
        var start = frame
        if horizontal {
            start.origin.x = from.minX + drawn.minX - content.minX
        } else {
            start.origin.y = from.minY + drawn.minY - content.minY
        }
        return start
    }

    /// A shelf appearing (#1838): its sections land at their slots
    /// transparent and fade in on the running glide.
    func fadeIn(_ sections: [Section]) {
        for section in sections {
            section.view.alphaValue = 0
            BarMotion.setAlpha(section.view, to: 1, animated: true)
        }
    }

    /// `plate` shrunk to nothing at its alignment anchor — its
    /// centre, or the end it is anchored to — so an appearing shelf
    /// grows from there and never moves an anchored edge.
    nonisolated static func collapsed(
        _ plate: CGRect,
        to alignment: KiwiShelf.Alignment,
        horizontal: Bool
    ) -> CGRect {
        let length = horizontal ? plate.width : plate.height
        let lead: CGFloat
        switch alignment {
        case .start: lead = 0
        case .center: lead = length / 2
        case .end: lead = length
        }
        return horizontal
            ? CGRect(
                x: plate.minX + lead,
                y: plate.minY,
                width: 0,
                height: plate.height
            )
            : CGRect(
                x: plate.minX,
                y: plate.minY + lead,
                width: plate.width,
                height: 0
            )
    }
}
