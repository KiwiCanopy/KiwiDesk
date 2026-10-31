import CoreGraphics

/// Where the pocket stands on a screen (#2678, #2784, #2793): the one
/// ladder the drawing (`pocketPlateSpecs`) and the landing
/// (`pocketLanding`) both read, so the two never disagree.
enum PocketPlace: Equatable {
    /// Its slot on a bar's edge under Several windows, AX.
    case section(CGRect)
    /// Under One window, just inside a bar's strip, AX (#2793).
    case inside(CGRect)
    /// The whole mark with no handle: under One window on an edge no
    /// bar's strip stands, sliding out of it, or at rest under Always
    /// (#2784 ▸ 8).
    case whole(slides: Bool)
    /// The handle, the pocket rising out of it.
    case handle

    /// Whether it is a shelf section, drawn in its shelf's panel.
    var isSection: Bool {
        if case .section = self { return true }
        return false
    }

    /// Whether it slides out of its edge as it comes (#2793).
    var slides: Bool {
        switch self {
        case .inside: true
        case .whole(let slides): slides
        case .section, .handle: false
        }
    }
}

extension KiwiCore {
    /// The pocket's place on `display` this pass.
    func pocketPlace(on display: DisplayID) -> PocketPlace {
        if let slot = pocketPlate.slots[display] { return .section(slot) }
        if let inside = pocketInsideFrame(on: display) {
            return .inside(inside)
        }
        // One window has no handle (#2793).
        if !pocketHoldsSeveral { return .whole(slides: true) }
        let shown = state.workspaces.allDisplays.first { $0.id == display }
        return shown.map(pocketRestsWhole) == true
            ? .whole(slides: false) : .handle
    }

    /// How far in from its frame's edge side the mark stands: the
    /// outer margin, save inside the strip, whose frame starts past
    /// it.
    static func pocketOuter(
        _ place: PocketPlace,
        shelf: KiwiShelf
    ) -> CGFloat {
        if case .inside = place { return 0 }
        return shelf.outerMargin
    }
}
