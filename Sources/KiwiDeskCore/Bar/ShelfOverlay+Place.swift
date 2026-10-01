import AppKit

/// Placing the sections on the strip (#1517, #1838). A section
/// joining grows out of the one it joins and fades in, a leaving one
/// shrinks back into it and fades out, and one already on the strip
/// glides from where its content was DRAWN — all on the plate
/// glide. A section re-lays its content for the new slot at once, so
/// a glide from its old frame jumped that content aside first.
extension ShelfOverlay {
    /// Stands each gliding section at its glide start, committed
    /// ahead of the plate glide (#1838): a joining section collapsed
    /// at the end facing the section it joins, transparent; one on
    /// the strip at `glideStart`.
    func standGlideStarts(
        _ sections: [Section],
        in strip: CGRect,
        horizontal: Bool
    ) {
        BarMotion.standCommitted {
            for section in sections
            where section.view.superview !== stripView {
                let frame = Self.slotFrame(section, in: strip)
                stripView.addSubview(
                    section.view,
                    positioned: .below,
                    relativeTo: divider
                )
                section.view.frame = Self.collapsed(
                    frame,
                    to: Self.facing(frame, others: sections, in: strip),
                    horizontal: horizontal
                )
                section.view.alphaValue = 0
            }
            for section in sections
            where section.view.superview === stripView {
                guard
                    let drawn = placedContent[ObjectIdentifier(section.view)]
                else { continue }
                section.view.frame = Self.glideStart(
                    from: section.view.frame,
                    drawn: drawn,
                    content: section.content,
                    to: Self.slotFrame(section, in: strip),
                    horizontal: horizontal
                )
            }
        }
    }

    /// A section's frame on the strip: origin and size in ONE
    /// write, so a section never re-lays at a new size from its old
    /// place.
    nonisolated static func slotFrame(
        _ section: Section,
        in strip: CGRect
    ) -> CGRect {
        CGRect(
            x: section.slot.minX - strip.minX,
            y: section.slot.minY - strip.minY,
            width: section.slot.width,
            height: section.slot.height
        )
    }

    func place(
        _ sections: [Section],
        in strip: CGRect,
        horizontal: Bool,
        animated: Bool
    ) {
        let wanted = sections.map(\.view)
        var leaving: [NSView] = []
        for view in stripView.subviews
        where view !== divider && view !== handle
            && !wanted.contains(where: { $0 === view })
        {
            guard animated, leavingViews[view] == nil else {
                if !animated { view.removeFromSuperview() }
                continue
            }
            // A section leaving shrinks back into the one it leaves.
            view.isHidden = false
            leaving.append(view)
            BarMotion.setFrame(
                view,
                to: Self.collapsed(
                    view.frame,
                    to: Self.facing(view.frame, others: sections, in: strip),
                    horizontal: horizontal
                ),
                animated: true
            )
            BarMotion.setAlpha(view, to: 0, animated: true)
        }
        if !leaving.isEmpty {
            let token = UUID()
            for view in leaving { leavingViews[view] = token }
            // A view wanted again before this lands left the set and
            // stays, one leaving again wears a later stamp, and one
            // another shelf took meanwhile is that shelf's to place
            // (#1838).
            BarMotion.afterGroupGlide { [weak self] in
                guard let self else { return }
                for view in leaving where self.leavingViews[view] == token {
                    if view.superview === self.stripView {
                        view.removeFromSuperview()
                    }
                    self.leavingViews[view] = nil
                }
            }
        }
        placedContent = placedContent.filter { key, _ in
            wanted.contains { ObjectIdentifier($0) == key }
        }
        for section in sections {
            let key = ObjectIdentifier(section.view)
            leavingViews[section.view] = nil
            let joining = section.view.superview !== stripView
            if joining {
                stripView.addSubview(
                    section.view,
                    positioned: .below,
                    relativeTo: divider
                )
            }
            let frame = Self.slotFrame(section, in: strip)
            BarMotion.setFrame(
                section.view,
                to: frame,
                animated: animated && !joining
            )
            BarMotion.setAlpha(section.view, to: 1, animated: animated)
            placedContent[key] = section.content
        }
    }

    /// Where a gliding section starts (#1838): `from` where the slot
    /// did not change or `content` keeps `drawn`'s offset in the
    /// section, else the new size placed so the content sits where
    /// it was drawn. A zero reading glides from `from`.
    nonisolated static func glideStart(
        from: CGRect,
        drawn: CGRect,
        content: CGRect,
        to frame: CGRect,
        horizontal: Bool
    ) -> CGRect {
        guard frame != from, drawn != .zero, content != .zero else {
            return from
        }
        let shift =
            horizontal ? drawn.minX - content.minX : drawn.minY - content.minY
        // Sub-point: a rounding difference between two renders'
        // end pads, never a re-anchoring.
        guard abs(shift) >= 0.5 else { return from }
        var start = frame
        if horizontal {
            start.origin.x = from.minX + shift
        } else {
            start.origin.y = from.minY + shift
        }
        return start
    }

    /// `frame` shrunk to nothing at `alignment`'s anchor — its
    /// centre, or the end it is anchored to.
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

    /// Which end of `frame` faces the other sections — where a
    /// joining section grows from and a leaving one shrinks to.
    nonisolated static func facing(
        _ frame: CGRect,
        others sections: [Section],
        in strip: CGRect
    ) -> KiwiShelf.Alignment {
        let before = sections.contains {
            slotFrame($0, in: strip).midX < frame.midX
                || slotFrame($0, in: strip).midY < frame.midY
        }
        return before ? .start : .end
    }
}
