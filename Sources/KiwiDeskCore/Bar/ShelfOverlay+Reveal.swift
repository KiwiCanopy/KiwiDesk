import AppKit

/// A hiding shelf's reveal and retract (#761): its content slides
/// in from the edge and back out through `BarMotion.playReveal`,
/// the panel ordered out only once the retract lands.
extension ShelfOverlay {
    /// Slides the content in; a retract in flight is replaced.
    func slideIn(edge: AppBarEdge, depth: CGFloat) {
        leavingSlides = false
        BarMotion.endReveal(content)
        content.alphaValue = 1
        BarMotion.playReveal(
            content,
            edge: edge,
            depth: depth,
            entering: true
        ) { [weak self] in
            guard let self, self.leaving == nil else { return }
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
        BarMotion.playReveal(
            content,
            edge: edge,
            depth: edge.isHorizontal ? strip.height : strip.width,
            entering: false
        ) { [weak self] in
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
