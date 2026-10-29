import AppKit

/// The pocket as a shelf section (#2678): one motion call site
/// reaches the shelf's content and the pocket's, each in its own
/// panel, so the pocket rides every reveal style, fade and glide the
/// shelf plays and never cuts.
extension ShelfOverlay {
    /// The contents a motion plays on, each with the view a grow
    /// fades: the shelf's, then the pocket's while it carries one.
    var motionContents: [(view: NSView, items: NSView)] {
        var all: [(view: NSView, items: NSView)] = [(content, stripView)]
        if pocket.isMounted { all.append((pocket.content, pocket.items)) }
        return all
    }

    /// Sets every content's alpha, the pocket's too.
    func setContentAlpha(_ alpha: CGFloat, animated: Bool) {
        for (view, _) in motionContents {
            if animated {
                BarMotion.setAlpha(view, to: alpha, animated: true)
            } else {
                view.alphaValue = alpha
            }
        }
    }

    /// Ends a reveal's motion on every content.
    func endRevealMotion() {
        for (view, items) in motionContents {
            BarMotion.endReveal(view, items: items)
        }
    }

    /// The plate a grow or an unfold reaches: the shelf's, grown to
    /// the pocket's slot, so the pocket comes out with the plate.
    func revealPlate(
        _ plate: CGRect,
        radius: CGFloat
    ) -> (frame: CGRect, radius: CGFloat) {
        (pocket.rest.map { plate.union($0) } ?? plate, radius)
    }

    /// The pocket's room for the motion about to play: a slide's run
    /// out over the margin, its slot for every other style, whose
    /// clip the content's own layer carries.
    func openPocketRoom(entering: Bool) {
        guard let drawn, let rest = pocket.rest else { return }
        let room: CGRect
        if case .slide = BarMotion.resolvedReveal(
            revealPath,
            entering: entering
        ) {
            room = Self.slideRoom(rest, edge: drawn.edge, gap: revealGap)
        } else {
            room = rest
        }
        pocket.placeRoom(
            pocket.placedRoom.map { $0.union(room) } ?? room,
            strip: drawn.strip
        )
    }

    /// Orders the pocket's panel in above the shelf's, or out where
    /// the shelf carries no pocket. A pocket joining a shown shelf
    /// fades in; one leaving fades out (`pocketLeft`).
    func syncPocketPanel(joined: Bool, left: Bool, animated: Bool) {
        guard let panel else { return }
        if left {
            pocketLeft(animated: animated)
            return
        }
        guard pocket.isMounted, panel.isVisible else { return }
        let fades = joined && animated && BarMotion.shelfGlideLength > 0
        if fades { pocket.content.alphaValue = 0 }
        pocket.orderIn(above: panel)
        if fades {
            BarMotion.runPlateGlide {
                BarMotion.setAlpha(pocket.content, to: 1, animated: true)
            }
        }
    }

    /// The pocket left a shelf that stays: its panel fades out and
    /// orders out on the glide's landing, unless it joined again.
    private func pocketLeft(animated: Bool) {
        guard pocket.isVisible else { return }
        guard animated, BarMotion.shelfGlideLength > 0 else {
            pocket.orderOut()
            return
        }
        BarMotion.runPlateGlide {
            BarMotion.setAlpha(pocket.content, to: 0, animated: true)
        }
        afterGlide { [weak self] in
            guard let self, !self.pocket.isMounted else { return }
            self.pocket.orderOut()
            self.pocket.content.alphaValue = 1
        }
    }
}
