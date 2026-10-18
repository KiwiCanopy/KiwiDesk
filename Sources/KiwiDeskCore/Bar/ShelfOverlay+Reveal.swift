import AppKit

/// A hiding shelf's reveal and retract (#761): its content slides
/// in from the edge and back out through `BarMotion.playReveal`,
/// the panel ordered out only once the retract lands.
extension ShelfOverlay {
    /// Slides the content in; a retract in flight is replaced.
    func slideIn(edge: AppBarEdge, depth: CGFloat) {
        // A slide-in takes the shelf back from a leave in flight.
        leaving = nil
        leavingSlides = false
        BarMotion.endReveal(content)
        content.alphaValue = 1
        let token = UUID()
        revealing = token
        let span = BarMotion.playReveal(
            content,
            edge: edge,
            depth: depth,
            entering: true
        )
        afterReveal(span) { [weak self] in
            guard let self, self.revealing == token, self.leaving == nil
            else { return }
            self.revealing = nil
            BarMotion.endReveal(self.content)
        }
    }

    /// Slides the content out and orders the panel out once it
    /// lands, unless a show meanwhile took the shelf back. Returns
    /// whether this call began the leave.
    func slideOut(edge: AppBarEdge, strip: CGRect) -> Bool {
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
            edge: edge,
            depth: edge.isHorizontal ? strip.height : strip.width,
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
