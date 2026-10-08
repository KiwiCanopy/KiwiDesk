import AppKit

/// The front-app segment joining or leaving a shown bar (#1903): it
/// grows out of the run's end it closes and shrinks back into it,
/// on the plate glide the shelf moves its sections on (#1838), the
/// same motion a section joining a fused shelf makes. Its glass cuts,
/// since a glass takes neither alpha nor geometry.
extension SpaceBarOverlay {
    /// The segment's views a grow moves, in drawing order.
    var frontGrowViews: [NSView] {
        [
            frontDivider, frontBox, frontBorder, frontAccentClip,
            frontIcon, frontGlyph, frontName,
        ]
    }

    /// Stands the just-laid segment collapsed at its leading edge
    /// and transparent, committed, then glides it open.
    func growFront(horizontal: Bool) {
        let views = frontGrowViews.filter { !$0.isHidden }
        let targets = views.map(\.frame)
        guard let lead = Self.leadingEdge(targets, horizontal: horizontal)
        else { return }
        BarMotion.standCommitted {
            for view in views {
                view.frame = Self.collapsed(
                    view.frame,
                    at: lead,
                    horizontal: horizontal
                )
                view.alphaValue = 0
            }
        }
        BarMotion.runPlateGlide {
            for (view, frame) in zip(views, targets) {
                BarMotion.setFrame(view, to: frame, animated: true)
                BarMotion.setAlpha(view, to: 1, animated: true)
            }
        }
    }

    /// Glides the shown segment shut into `end` — where the run now
    /// ends, so it shrinks into the run as the run re-places rather
    /// than under its last item — then hides it, unless a render
    /// drew it again meanwhile; false, shrinking nothing, where no
    /// glide plays (Reduce Motion, the shelf animation off). It
    /// stops being a target and its glass cuts at once.
    func shrinkFront(into end: CGFloat, horizontal: Bool) -> Bool {
        let views = frontGrowViews.filter { !$0.isHidden }
        guard BarMotion.shelfGlideLength > 0, !views.isEmpty else {
            return false
        }
        // A segment pinned outside the run sits in another host,
        // where the run's end means nothing: it shuts in place.
        let lead =
            frontDivider.superview === itemRun
            ? end
            : Self.leadingEdge(views.map(\.frame), horizontal: horizontal)
                ?? end
        let leave = UUID()
        frontLeave = leave
        frontWindows = []
        updateFrontGlass(
            nil,
            radius: 0,
            style: lastShown?.style ?? SpaceBarLook()
        )
        BarMotion.runPlateGlide {
            for view in views {
                BarMotion.setFrame(
                    view,
                    to: Self.collapsed(
                        view.frame,
                        at: lead,
                        horizontal: horizontal
                    ),
                    animated: true
                )
                BarMotion.setAlpha(view, to: 0, animated: true)
            }
        }
        afterFrontGlide { [weak self] in
            guard let self, self.frontLeave == leave else { return }
            self.frontLeave = nil
            for view in views {
                view.isHidden = true
                view.alphaValue = 1
            }
        }
        return true
    }

    /// Where the segment starts along the axis: its rule's end.
    nonisolated static func leadingEdge(
        _ frames: [CGRect],
        horizontal: Bool
    ) -> CGFloat? {
        frames.map { horizontal ? $0.minX : $0.minY }.min()
    }

    /// `frame` shut to nothing at `lead` along the axis.
    nonisolated static func collapsed(
        _ frame: CGRect,
        at lead: CGFloat,
        horizontal: Bool
    ) -> CGRect {
        horizontal
            ? CGRect(x: lead, y: frame.minY, width: 0, height: frame.height)
            : CGRect(x: frame.minX, y: lead, width: frame.width, height: 0)
    }
}
