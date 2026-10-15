import AppKit

/// KiwiVision's float veils (#2103 ruling 3): the float tier sits
/// above the focused window and so above the plate, and each float
/// there wears the plate's veil on a panel of its own — above its
/// mark and sized to its ring, so both dim with it (owner ruling,
/// option A, 2026-10-15).
extension KiwiCore {
    /// The floats the float tier lifts above `target`: none while
    /// `target` is itself an effective float, since nothing tiled is
    /// focused (#1286). The one set the float raise and the veils
    /// read, so the veils never miss a float the raise lifted nor
    /// veil one the plate already covers.
    func floatsAboveFocus(of target: WindowID) -> [WindowID] {
        guard !isEffectiveFloatOnActiveSpace(target) else { return [] }
        return floatLayerTargets()
    }

    /// Re-draws the veils above `focus`, the ring's focused window
    /// (nil while nothing is, or an own key window stands in front:
    /// then nothing is veiled). Rides `updateVision`.
    func updateFloatDims(above focus: WindowID?, reassertOrder: Bool) {
        var request = floatDimRequest(above: focus)
        let wanted = Set(request.floats.map(\.id))
        windowServer.request(
            wanted,
            for: .floatDim,
            keeping: floatDims.shown.union(floatDims.dormant)
                .subtracting(wanted)
        )
        request.tracked = windowServer.isActive
        floatDims.sync(
            request,
            alive: Set(state.windows.all.map(\.id)),
            reassert: reassertOrder
        )
    }

    /// What the veils draw now. Kept clear, as the plate keeps them
    /// clear or a ring would skip them: a transient overlay or a
    /// raised-layer panel (#300), a native-fullscreen or presenting
    /// float (#1788), a parked one, and any on a screen whose plate
    /// stands down.
    func floatDimRequest(above focus: WindowID?) -> FloatDimManager.Request {
        let style = tiler.settings.borderStyle
        let outset =
            style.enabled && style.unfocusedEnabled ? style.width : 0
        let carried = stickyReachCarried()
        let ids = vision.isOn ? focus.map(floatsAboveFocus(of:)) ?? [] : []
        let floats = ids.compactMap { id -> FloatDimManager.Float? in
            guard id != focus, let window = state.windows[id],
                !window.isTransientOverlay, !window.isRaisedLayer,
                !window.isFullscreen,
                !tiler.looksStashed(window.frame),
                !presents(id, at: window.frame),
                !visionStandsDown(at: window.frame)
            else { return nil }
            return FloatDimManager.Float(
                id: id,
                frame: window.frame,
                outset: outset,
                cornerRadius: borders.cornerRadius(for: id) + outset,
                anchor: stickyMarks.panelNumber(of: id) ?? id.raw,
                spans: carried.contains(id)
            )
        }
        return FloatDimManager.Request(
            floats: floats,
            on: vision.isOn,
            dim: CGFloat(appWide.visionDim / 100),
            blur: kiwiVisionDrawsBlur,
            tracked: windowServer.isActive
        )
    }

    /// Whether the screen holding `frame` stands its plate down, as
    /// the shelf last judged it — no WindowServer read of its own.
    private func visionStandsDown(at frame: CGRect) -> Bool {
        guard
            let display = TilingEngine.screen(containing: frame)?
                .kiwiDisplayID
        else { return false }
        return vision.standDown.contains(display)
    }
}
