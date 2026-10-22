import AppKit
import CoreGraphics

/// Manages the overflow marks (#2235): one overlay per run end
/// that hides windows, following its anchor window through the
/// same `FollowSource` decisions as the sticky mark.
@MainActor
public final class OverflowMarkManager {
    /// One mark as the core wants it drawn.
    struct Spec {
        let mark: OverflowMark
        /// The anchor's steady-state frame (AX).
        let frame: CGRect
        /// VoiceOver's name for it.
        let name: String
        /// The shelf look, gated for Reduce transparency.
        let shelf: KiwiShelf
        /// Joins every Desktop: the anchor is carried (#2149).
        let spans: Bool
    }

    private(set) var overlays: [OverflowMark.Key: OverflowMarkOverlay] =
        [:]

    /// The hover peek the marks feed (#1946), the bars' one.
    var peek: BarPeek?
    /// The displays whose shelf the last bar pass stood down; a mark
    /// wears the shelf's look and stands down with it (#2235).
    var standingDown: Set<DisplayID> = []
    /// VoiceOver's press: the window menu of a mark's windows.
    var openMenu: @MainActor (OverflowMark, NSView) -> Void = { _, _ in }

    /// Whether the WindowServer stream delivers the window's events
    /// (`WindowServerWatch.hears`, #2275).
    var isWindowServerTracked: @MainActor (WindowID) -> Bool = { _ in
        false
    }
    /// Whether our own animation drives the window (#594).
    var isAnimating: @MainActor (WindowID) -> Bool = { _ in false }
    /// The engine's pending target frame (#881).
    var commandedFrame: @MainActor (WindowID) -> CGRect? = { _ in nil }

    #if DEBUG
        /// Whether a mark orders its panel in; off in both
        /// `makeTestCore` twins (#1894's shape, as the shelf's).
        var ordersPanels = true
    #endif

    public init() {}

    /// Windows carrying a mark.
    var anchors: Set<WindowID> { Set(overlays.values.map(\.mark.anchor)) }

    /// Synchronizes the drawn marks to `desired`.
    func sync(_ desired: [Spec], reassertOrder: Bool = false) {
        let wanted = Set(desired.map(\.mark.key))
        for (key, overlay) in overlays where !wanted.contains(key) {
            if peek?.shown?.view === overlay.view { peek?.dismiss() }
            overlay.hide()
            overlays[key] = nil
        }
        for spec in desired {
            let overlay = overlays[spec.mark.key] ?? made(spec.mark)
            overlays[spec.mark.key] = overlay
            // A re-anchored mark lists other windows from another
            // place, so a peek open on it would read stale.
            if overlay.mark != spec.mark,
                peek?.shown?.view === overlay.view
            {
                peek?.dismiss()
            }
            overlay.set(spec.mark, name: spec.name, shelf: spec.shelf)
            overlay.setSpans(spec.spans)
            overlay.update(
                frame: FollowSource.syncFrame(
                    spec: spec.frame,
                    held: overlay.lastFrame,
                    animating: isAnimating(spec.mark.anchor),
                    commanded: commandedFrame(spec.mark.anchor)
                )
            )
            if BorderManager.ordersOverlay(
                reassert: reassertOrder,
                needsOrder: overlay.needsOrder,
                tracked: isWindowServerTracked(spec.mark.anchor)
            ) {
                overlay.order()
            }
        }
    }

    /// Follows a moving or animating anchor
    /// (`FollowSource.renderFrame`, #285, #594, #677).
    func follow(
        _ id: WindowID,
        windowFrame: CGRect,
        source: FollowSource,
        pin: SizePin?
    ) {
        guard
            let frame = source.renderFrame(
                reported: windowFrame,
                pin: pin,
                wsTracked: isWindowServerTracked(id),
                animating: isAnimating(id)
            )
        else { return }
        each(id) { $0.update(frame: frame) }
    }

    /// Repositions from WindowServer bounds (the watch's frame
    /// phase).
    func reposition(_ id: WindowID, windowFrame: CGRect) {
        each(id) { $0.update(frame: windowFrame) }
    }

    /// Re-stacks above the anchor (the watch's restack phase).
    func reassert(_ id: WindowID) {
        each(id) { $0.order() }
    }

    /// Owes `id`'s marks a stack at the next sync: carried.
    func oweOrder(_ id: WindowID) {
        each(id) { $0.oweOrder() }
    }

    /// The shelf a mark panel wears — the peek wears it too.
    func shelf(drawnIn window: NSWindow) -> KiwiShelf? {
        overlays.values.first { $0.panel === window }?.view.shelfLook
    }

    /// Removes and hides every mark.
    func clear() {
        for overlay in overlays.values {
            if peek?.shown?.view === overlay.view { peek?.dismiss() }
            overlay.hide()
        }
        overlays = [:]
    }

    private func each(
        _ id: WindowID,
        _ body: (OverflowMarkOverlay) -> Void
    ) {
        for overlay in overlays.values where overlay.mark.anchor == id {
            body(overlay)
        }
    }

    private func made(_ mark: OverflowMark) -> OverflowMarkOverlay {
        let overlay = OverflowMarkOverlay(mark: mark)
        #if DEBUG
            overlay.ordersPanel = ordersPanels
        #endif
        let view = overlay.view
        view.onHover = { [weak self, weak overlay] inside in
            guard let self, let overlay else { return }
            self.report(overlay, inside: inside)
        }
        view.onClick = { [weak self, weak overlay] in
            guard let overlay else { return }
            self?.peek?.show(
                overlay.view,
                source: .run(overlay.mark.windows),
                space: overlay.mark.space,
                edge: overlay.mark.end.peekEdge
            )
        }
        view.onPress = { [weak self, weak overlay] in
            guard let self, let overlay else { return }
            self.openMenu(overlay.mark, overlay.view)
        }
        overlay.onPanelPress = { [weak self] hit, type in
            self?.peek?.pressed(on: hit, type: type)
        }
        return overlay
    }

    /// What the pointer rests on, handed to the peek from the
    /// mark's one hover gate.
    private func report(_ overlay: OverflowMarkOverlay, inside: Bool) {
        let view = overlay.view
        peek?.pointer(
            in: view,
            on: inside ? view : nil,
            source: inside ? .run(overlay.mark.windows) : nil,
            space: overlay.mark.space,
            edge: overlay.mark.end.peekEdge
        )
    }
}

extension OverflowMark.End {
    /// The edge the peek opens away from: into the run.
    var peekEdge: AppBarEdge {
        switch self {
        case .top: .top
        case .bottom: .bottom
        case .left: .left
        case .right: .right
        }
    }
}
