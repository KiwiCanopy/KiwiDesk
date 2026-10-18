import AppKit

/// A hiding shelf's reveal and retract (#761): its content grows
/// out of the hidden mark and back into it through
/// `BarMotion.playReveal`, the panel ordered out only once the
/// retract lands.
extension ShelfOverlay {
    /// Where the hidden mark sits in the content, from its frame
    /// and the shelf's strip, both AX coordinates.
    func setRevealOrigin(mark: CGRect?, strip: CGRect) {
        guard let mark else {
            revealOrigin = nil
            return
        }
        let local = mark.offsetBy(dx: -strip.minX, dy: -strip.minY)
        revealOrigin =
            content.isFlipped
            ? local
            : CGRect(
                x: local.minX,
                y: strip.height - local.maxY,
                width: local.width,
                height: local.height
            )
    }

    /// The mark, or the middle of the content where none is known.
    private var origin: CGRect {
        revealOrigin
            ?? CGRect(x: content.bounds.midX, y: 0, width: 0, height: 0)
    }

    /// Grows the content out of the mark; a retract in flight is
    /// replaced.
    func revealIn() {
        // A reveal takes the shelf back from a leave in flight.
        leaving = nil
        leavingSlides = false
        BarMotion.endReveal(content)
        content.alphaValue = 1
        let token = UUID()
        revealing = token
        let span = BarMotion.playReveal(
            content,
            origin: origin,
            entering: true
        )
        afterReveal(span) { [weak self] in
            guard let self, self.revealing == token, self.leaving == nil
            else { return }
            self.revealing = nil
            BarMotion.endReveal(self.content)
        }
    }

    /// Shrinks the content back into the mark and orders the panel
    /// out once it lands, unless a show meanwhile took the shelf
    /// back. Returns whether this call began the leave.
    func retractOut() -> Bool {
        guard leaving == nil else { return false }
        let token = UUID()
        leaving = token
        leavingSlides = true
        // The managers hid the sections; the shelf draws them on
        // until the retract lands, as its fade does (#1838).
        for view in stripView.subviews
        where view !== divider && view !== handle {
            view.isHidden = false
        }
        BarMotion.endReveal(content)
        revealing = nil
        let span = BarMotion.playReveal(
            content,
            origin: origin,
            entering: false
        )
        afterReveal(span) { [weak self] in
            guard let self, self.leaving == token else { return }
            self.leaving = nil
            self.leavingSlides = false
            self.panel?.orderOut(nil)
            BarMotion.endReveal(self.content)
            self.onLeft()
        }
        return true
    }
}
