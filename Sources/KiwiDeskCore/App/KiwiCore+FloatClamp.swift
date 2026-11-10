import CoreGraphics

/// Keeps a floating window's title bar clear of a reserved, painted
/// TOP strip (#242), the one correction a float takes (#3163, owner
/// ruling 2026-11-10). A float is never resized to fit, and a bar
/// on the bottom or a side never moves one: the user places and
/// sizes a float. Floats sit outside all layout geometry
/// (`TilingEngine.layoutInput`), so nothing else stops one sliding
/// under the strip and leaving it ungrabbable.
///
/// Strips are read from the bars the managers actually painted
/// (`shownStrips`) on the edges the layout reserves
/// (`reservedStrips`, #1524), never re-derived here: a second
/// derivation drifts from what is on screen.
extension KiwiCore {
    /// `frame` pushed down clear of every reserved top strip painted
    /// for the window's own space — or for `space`, the one a
    /// traveler RENDERS on (#1217) — at its own size, or unchanged.
    /// A float taller than the room below runs off the screen's
    /// bottom (#3163). Callers with a fresher read than state (a
    /// fresh drop, a resize target) pass their own frame in.
    func floatFrameClampedClearOfBars(
        _ id: WindowID,
        frame: CGRect,
        space rendering: SpaceID? = nil
    ) -> CGRect {
        guard
            let space = rendering ?? state.workspaces.space(of: id)
        else { return frame }
        var result = frame
        let inset = floatRingInset
        // Each push is monotonic, so with two strips on the top
        // edge the deeper one's push subsumes the other's.
        for (strip, edge) in reservedStrips(forSpace: space)
        where edge == .top {
            result = AppBarGeometry.pushedBelow(
                result,
                strip: strip,
                inset: inset
            )
        }
        return result
    }

    /// Re-asserts the top-bar push for every floating window under
    /// a painted bar, across all displays. The structural safety
    /// net, run from `retile()` after the bars are synced: a window
    /// turned floating under an existing bar, or a bar switched on
    /// over an existing float, is corrected here. Drag and resize
    /// clamp their own fresh frame directly.
    func clampFloatsClearOfBars() {
        for space in spacesWithShownBars {
            guard let workspace = state.workspaces[space]
            else { continue }
            for id in workspace.windows {
                guard let window = state.windows[id] else { continue }
                // Judge the frame the window WOULD show, never the
                // one it is leaving: a pending capture is where the
                // restore pass just sent it (#1352/#1177), corrected
                // WITH the window so the echo consumes it (#412),
                // and a frame sent and not yet echoed outranks state
                // (#3157); a push of the stale frame lands after the
                // delivery and undoes it.
                let pending = tiler.stashOriginal(id)
                guard
                    let pushed = floatBarPush(
                        id,
                        frame: wouldBeFrame(of: window),
                        in: workspace
                    )
                else { continue }
                if pending != nil {
                    tiler.seedStash(id, frame: pushed)
                }
                // A slide in flight is retargeted rather than
                // snapped.
                tiler.applyFrame(
                    id,
                    from: window.frame,
                    to: pushed,
                    animated: tiler.animation.targetFrame(window: id)
                        != nil
                )
            }
        }
    }

    /// The sweep's per-window verdict, the one copy (#1358): the
    /// frame the push would move `id` to, or nil where the sweep
    /// would leave it — not an effective float, native fullscreen,
    /// its space under no painted bar, or already clear. Handed
    /// `frame` rather than reading the state frame, so the resize
    /// arm can ask about the frame that just arrived.
    func floatBarPush(
        _ id: WindowID,
        frame: CGRect,
        in workspace: Space? = nil
    ) -> CGRect? {
        guard
            let workspace = workspace
                ?? state.workspaces.space(of: id).flatMap({
                    state.workspaces[$0]
                }),
            spacesWithShownBars.contains(workspace.id),
            let window = state.windows[id],
            // A maximized float fills its screen by design (#3036).
            !isMaximizedFloat(window),
            // A native-fullscreen window keeps its slot but lives
            // on its own macOS Space (#670).
            !window.isFullscreen,
            // Nor one presenting over its whole screen: the push
            // would move a slide show under nothing and its stamp
            // read the show's first focus as a bounce (#1787).
            !coversAsShow(window, at: frame),
            // A layout's park on a tiling-off Space stays put, as the
            // stranded-float recovery leaves it (#3008).
            !(state.isTilingOff(workspace.id) && tiler.looksStashed(frame)),
            // EFFECTIVE float, never the flag (#1178).
            EffectiveFloat.applies(
                isFloating: window.isFloating,
                mode: state.placementMode(of: workspace)
            )
        else { return nil }
        // One fold over every strip, one apply: applyFrame is async,
        // so a per-strip apply re-read the same stale state frame.
        let pushed = floatFrameClampedClearOfBars(id, frame: frame)
        return pushed == frame ? nil : pushed
    }

    /// Whether `window` is the Maximize of the Space it renders on.
    private func isMaximizedFloat(_ window: ManagedWindow) -> Bool {
        state.renderSpace(of: window)
            .flatMap { state.workspaces[$0] }
            .map { state.maximizedFloat(of: $0) == window.id } ?? false
    }

    /// Every space with at least one painted strip: the App
    /// Bars' own spaces, plus the space each Space-Bar-covered
    /// display is showing (#293: per-display bar, occludes the
    /// current space).
    private var spacesWithShownBars: Set<SpaceID> {
        var spaces = Set(appBars.shownStrips.map(\.space))
        for (display, _, _) in spaceBars.shownStrips {
            guard
                let space =
                    state.workspaces.currentSpace(on: display)
            else { continue }
            spaces.insert(space)
        }
        return spaces
    }
}
