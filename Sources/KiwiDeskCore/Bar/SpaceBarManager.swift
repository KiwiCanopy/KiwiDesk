import AppKit

/// Space Bar overlay manager across displays (#293, `AppBarManager`).
@MainActor
public final class SpaceBarManager {
    /// One display's resolved bar configuration.
    public struct Bar {
        public let display: DisplayID
        public let items: [SpaceBarOverlay.Item]
        /// Trailing front-app segment app data.
        let frontApp: SpaceBarItemView.App?
        /// Window ID associated with the front-app segment
        /// (`showsTitle(of:)`).
        let frontWindow: WindowID?
        public let strip: CGRect
        public let style: SpaceBarLook
        /// Mark indicator colors (#429, `StickyStyle`, `FloatingStyle`).
        let stateMarkColors: StateMarkColors

        init(
            display: DisplayID,
            items: [SpaceBarOverlay.Item],
            frontApp: SpaceBarItemView.App? = nil,
            frontWindow: WindowID? = nil,
            strip: CGRect,
            style: SpaceBarLook,
            stateMarkColors: StateMarkColors
        ) {
            self.display = display
            self.items = items
            self.frontApp = frontApp
            self.frontWindow = frontWindow
            self.strip = strip
            self.style = style
            self.stateMarkColors = stateMarkColors
        }
    }

    /// Selection callback (`KiwiCore.focusSpace`).
    public var onSelectSpace: @MainActor (SpaceID) -> Void = {
        _ in
    }

    /// What a glyph or `+n` click does, and a glyph's tooltip
    /// (#1528) — Core sets both at bootstrap.
    let glyphActions = SpaceBarGlyphActions()
    /// The shelf's context menus (#1518), set by Core at bootstrap.
    weak var contextMenus: BarContextMenus?

    /// The menu bar item's layer and Space mark (#1413), fired
    /// on change only since the bar refreshes on every retile.
    /// Internal: `KiwiCore.onStatusSpaceMarkChange` is the one
    /// door the GUI has, by visibility.
    var onStatusMarkChange: @MainActor (StatusSpaceMark) -> Void = {
        _ in
    }
    private(set) var statusMark: StatusSpaceMark?
    /// The live Spaces the profile does not hold (#1790), fired on
    /// change only, as the status mark is — Settings ▸ Spaces draws
    /// them. Internal: `KiwiCore.onLiveOnlySpacesChange` is the door.
    var onLiveOnlyChange: @MainActor ([LiveOnlySpace]) -> Void = { _ in }
    private(set) var liveOnly: [LiveOnlySpace] = []

    func publishLiveOnly(_ spaces: [LiveOnlySpace]) {
        guard spaces != liveOnly else { return }
        liveOnly = spaces
        onLiveOnlyChange(spaces)
    }

    /// The chip the pointer rests on and the strip it drew: the
    /// strip keeps it until the pointer leaves, so a click cannot
    /// slide another app under the pointer (#1528 item 21).
    private(set) var stripHold: (space: SpaceID, drawn: SpaceBarStrip.Drawn)?
    /// Fires when a hold ends, so the strip re-centres — Core
    /// wires it to a deferred `updateBars()`, since a hold can end
    /// inside the render or relayout that refresh would nest in.
    var onStripReleased: @MainActor () -> Void = {}

    private var overlays: [DisplayID: SpaceBarOverlay] = [:]
    /// Active visible bars painted on screen.
    private var shownBars: [Bar] = []

    public init() {}

    /// Displays currently showing a bar.
    public var shownDisplays: Set<DisplayID> {
        Set(shownBars.map(\.display))
    }

    /// Painted strips with display and edge metadata (#242, QA 2026-07-19).
    public var shownStrips:
        [(
            display: DisplayID, strip: CGRect,
            edge: AppBarEdge
        )]
    {
        shownBars.map {
            (
                display: $0.display,
                strip: $0.strip,
                edge: $0.style.edge
            )
        }
    }

    /// Whether a painted bar's front segment presents title for
    /// `id` — on either channel, drawn or announced, so it is NOT
    /// gated on the text edge: announced stale is as wrong as
    /// drawn stale (review 2026-08-20, #937).
    public func showsTitle(of id: WindowID) -> Bool {
        shownBars.contains { $0.frontWindow == id }
    }

    func publishStatusMark(_ mark: StatusSpaceMark) {
        guard mark != statusMark else { return }
        statusMark = mark
        onStatusMarkChange(mark)
    }

    /// Synchronizes visible bar overlays across displays. The
    /// validity filter here — not the overlay's identical guard —
    /// is the one the float clamp depends on; never simplify it
    /// away as redundant.
    public func sync(_ bars: [Bar]) {
        let valid = bars.filter {
            !$0.items.isEmpty
                && $0.strip.width >= 1 && $0.strip.height >= 1
        }
        shownBars = valid
        // A hold on a Space no bar draws any more has no chip
        // left to report its exit (#1528 item 21).
        if let hold = stripHold,
            !valid.contains(where: {
                $0.items.contains { $0.space == hold.space }
            })
        {
            stripHold = nil
        }
        let wanted = Set(valid.map(\.display))
        // Hidden, never dropped: the section's root keeps its place
        // on its shelf, so a bar coming back is the same section
        // re-shown (#1838).
        for (id, overlay) in overlays
        where !wanted.contains(id) {
            overlay.hide()
        }
        for bar in valid {
            overlay(for: bar.display).show(
                items: bar.items,
                frontApp: bar.frontApp,
                strip: bar.strip,
                style: bar.style,
                stateMarkColors: bar.stateMarkColors
            )
        }
    }

    /// The strip `space`'s chip keeps while the pointer rests on
    /// it; nil lets it centre.
    func heldStrip(of space: SpaceID) -> SpaceBarStrip.Drawn? {
        stripHold.flatMap { $0.space == space ? $0.drawn : nil }
    }

    /// The pointer entering or leaving a Space chip. Leaving the
    /// held chip — or entering another before its exit arrives —
    /// ends the hold and asks for the re-centring render.
    func stripHover(
        _ space: SpaceID,
        _ drawn: SpaceBarStrip.Drawn?,
        inside: Bool
    ) {
        if inside, let drawn {
            let replaced = stripHold.map { $0.space != space } ?? false
            stripHold = (space, drawn)
            if replaced { onStripReleased() }
            return
        }
        guard !inside, stripHold?.space == space else { return }
        stripHold = nil
        onStripReleased()
    }

    /// Hit-tests global screen point against space items (#372).
    public func spaceItem(atGlobal point: CGPoint) -> SpaceID? {
        for overlay in overlays.values {
            if let space = overlay.spaceItem(atGlobal: point) {
                return space
            }
        }
        return nil
    }

    /// Updates drag-hover highlight state across overlays.
    public func setDragHover(_ space: SpaceID?) {
        overlays.values.forEach { $0.setDragHover(space) }
    }

    /// Starts spring-load progress sweep on target space overlay.
    public func beginSpringSweep(
        on space: SpaceID,
        duration: TimeInterval,
        delay: TimeInterval
    ) {
        overlays.values.forEach {
            $0.beginSpringSweep(
                on: space,
                duration: duration,
                delay: delay
            )
        }
    }

    /// Clears drag hover and spring sweep visual indicators.
    public func clearDragFeedback() {
        overlays.values.forEach { $0.clearDragFeedback() }
    }

    /// Updates drag autoscroll cursor position across overlays (#385).
    public func updateDragAutoScroll(atGlobal point: CGPoint) {
        overlays.values.forEach {
            $0.updateDragAutoScroll(atGlobal: point)
        }
    }

    /// Cancels active drag autoscroll across all overlays.
    public func endDragAutoScroll() {
        overlays.values.forEach { $0.cancelDragAutoScroll() }
    }

    /// Drops the overlays of displays outside `live` — the
    /// connected ones, and those whose shelf is still fading, which
    /// the caller adds; a display still live keeps its hidden
    /// overlay (#1838).
    public func retire(except live: Set<DisplayID>) {
        for (id, overlay) in overlays where !live.contains(id) {
            overlay.hide()
            overlays[id] = nil
        }
    }

    /// The section a display's shelf places, while it shows
    /// (#1517).
    func shownOverlay(on display: DisplayID) -> SpaceBarOverlay? {
        guard let overlay = overlays[display], overlay.isVisible
        else { return nil }
        return overlay
    }

    #if DEBUG
        /// Test seam: overlay backing a specific display.
        func overlayForTesting(
            _ display: DisplayID
        ) -> SpaceBarOverlay? {
            overlays[display]
        }
    #endif

    private func overlay(
        for display: DisplayID
    ) -> SpaceBarOverlay {
        if let existing = overlays[display] { return existing }
        let overlay = SpaceBarOverlay()
        overlay.onSelect = { [weak self] space in
            self?.onSelectSpace(space)
        }
        overlay.glyphActions = glyphActions
        overlay.contextMenus = contextMenus
        overlay.onStripHover = { [weak self] space, drawn, inside in
            self?.stripHover(space, drawn, inside: inside)
        }
        overlays[display] = overlay
        return overlay
    }
}
