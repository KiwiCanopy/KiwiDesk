import AppKit

/// Placing the sections on the strip (#1517, #1838). A section
/// joining grows out of the one it joins and fades in, a leaving one
/// shrinks back into it and fades out, and one already on the strip
/// glides from where its content was DRAWN — all on the plate
/// glide. A section re-lays its content for the new slot at once, so
/// a glide from its old frame jumped that content aside first.
extension ShelfOverlay {
    /// Stands each gliding section at its glide start and COMMITS
    /// it: the animator starts a frame glide from the layer's
    /// PRESENTATION, which lags a model write until the transaction
    /// commits — a start stood at 569 animated from 0 until the
    /// flush (device, #1838) — so a stood start that was not flushed
    /// glided from the old frame, the content jumping aside first.
    func standGlideStarts(
        _ sections: [Section],
        in strip: CGRect,
        horizontal: Bool
    ) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for section in sections
        where section.view.superview !== stripView {
            // A section joining grows out of the one it joins, from
            // the side facing it (owner, device 2026-09-30).
            let frame = Self.slotFrame(section, in: strip)
            stripView.addSubview(
                section.view,
                positioned: .below,
                relativeTo: divider
            )
            section.view.frame = Self.collapsed(
                frame,
                toward: Self.facing(frame, others: sections, in: strip),
                horizontal: horizontal
            )
            section.view.alphaValue = 0
        }
        for section in sections
        where section.view.superview === stripView {
            guard let drawn = placedContent[ObjectIdentifier(section.view)]
            else { continue }
            section.view.frame = Self.glideStart(
                from: section.view.frame,
                drawn: drawn,
                content: section.content,
                to: Self.slotFrame(section, in: strip),
                horizontal: horizontal
            )
        }
        CATransaction.commit()
        CATransaction.flush()
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
            guard animated, !leavingViews.contains(view) else {
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
                    toward: Self.facing(
                        view.frame,
                        others: sections,
                        in: strip
                    ),
                    horizontal: horizontal
                ),
                animated: true
            )
            BarMotion.setAlpha(view, to: 0, animated: true)
        }
        if !leaving.isEmpty {
            leavingViews.formUnion(leaving)
            // A view wanted again before this lands left the set,
            // and stays: removing it re-joined it a second time
            // (device, #1838).
            BarMotion.afterGroupGlide { [weak self] in
                guard let self else { return }
                for view in leaving where self.leavingViews.contains(view) {
                    view.removeFromSuperview()
                    self.leavingViews.remove(view)
                }
            }
        }
        placedContent = placedContent.filter { key, _ in
            wanted.contains { ObjectIdentifier($0) == key }
        }
        for section in sections {
            let key = ObjectIdentifier(section.view)
            leavingViews.remove(section.view)
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

    /// Where a gliding section starts. Content that keeps its
    /// offset inside the section — `content`, re-laid for the new
    /// slot, where `drawn` was — is a RESIZE: the section glides
    /// from `from`, size included, the new row revealed from its
    /// anchored end (a switch between two Spaces with an App Bar).
    /// Content re-anchored inside its slot — centred across the
    /// lone strip, at the end of a fused one — starts at the new
    /// size, placed so the content sits where it was drawn, since
    /// the old bounds would clip it. A slot that did not change
    /// moves the section not at all, whatever its content did: a
    /// row re-centring inside the whole strip is the section's own
    /// render's, and a start that held it slid the section instead
    /// (device, #1838). A zero reading glides from `from`.
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

    /// `frame` shrunk to nothing at its `anchor` end.
    nonisolated static func collapsed(
        _ frame: CGRect,
        toward anchor: KiwiShelf.Alignment,
        horizontal: Bool
    ) -> CGRect {
        collapsed(frame, to: anchor, horizontal: horizontal)
    }
}
