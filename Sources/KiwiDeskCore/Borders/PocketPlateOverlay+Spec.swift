import AppKit

extension PocketPlateOverlay {
    /// What one display's pocket draws: its screen, its windows,
    /// its frame (AppKit), the gated shelf, the mark's colour, the
    /// edge it stands on and VoiceOver's name.
    struct Spec: Equatable {
        let display: DisplayID
        /// The windows it lists.
        let windows: [WindowID]
        let frame: CGRect
        let shelf: KiwiShelf
        let markHex: String
        /// The empty pocket at rest, drawn faded; lit, it shows full.
        let faded: Bool
        /// A dragged window over it that a drop would take.
        let dropHovered: Bool
        let name: String
        /// The edge its handle stands on, nil for a bar's section.
        var handle: AppBarEdge? = nil
        /// Out of its handle (a dwell or push, a drag), at this side.
        var risen = false
        /// The pointer on a resting handle: its kiwis peek (#2807).
        var peeking = false
        var risenSide: CGFloat = 0
        /// The shelf's outer margin, between the edge and the handle.
        var outer: CGFloat = 0
        /// The whole mark stands at rest on an edge no bar shows,
        /// with no handle (#2784 ▸ 8).
        var whole = false
        /// The One-window pocket, which slides out of its edge as it
        /// comes and back as it goes (#2793).
        var slides = false
    }
}
