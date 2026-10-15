import AppKit

/// KiwiVision's float veils (#2103 ruling 3): the float tier sits
/// above the focused window and so above the plate, and each float
/// there wears the plate's veil on a panel of its own — above its
/// chrome and sized to its ring, so its mark and ring dim with it
/// (owner ruling, option A, 2026-10-15).
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
        // Off, nothing is kept: the sync retires every veil.
        windowServer.request(
            wanted,
            for: .floatDim,
            keeping: vision.isOn
                ? floatDims.shown.union(floatDims.dormant)
                    .subtracting(wanted) : []
        )
        request.tracked = windowServer.isActive
        floatDims.sync(
            request,
            alive: Set(state.windows.all.map(\.id)),
            reassert: reassertOrder
        )
    }

    /// What the veils draw now. Kept clear: any window a ring
    /// skips (`isRingOverlay`, `ringFillsDisplay`), a raised-layer
    /// panel, a parked float and any on a screen whose plate
    /// stands down. A veil covers the float's ring as drawn and
    /// orders above its topmost chrome.
    func floatDimRequest(above focus: WindowID?) -> FloatDimManager.Request {
        let carried = stickyReachCarried()
        let ids = vision.isOn ? focus.map(floatsAboveFocus(of:)) ?? [] : []
        let floats = ids.compactMap { id -> FloatDimManager.Float? in
            guard id != focus, let window = state.windows[id],
                !isRingOverlay(id), !ringFillsDisplay(id),
                !window.isRaisedLayer,
                !tiler.looksStashed(window.frame),
                !visionStandsDown(at: window.frame)
            else { return nil }
            let outline = borders.ringOutline(of: id)
            return FloatDimManager.Float(
                id: id,
                frame: window.frame,
                outset: outline?.reach ?? 0,
                cornerRadius: outline?.cornerRadius
                    ?? borders.cornerRadius(for: id),
                anchor: topmostChrome(of: id),
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

    /// The window `id`'s veil orders directly above
    /// (`FloatDimManager.anchor`).
    func topmostChrome(of id: WindowID) -> CGWindowID {
        FloatDimManager.anchor(
            chrome: [borders.frontRing(of: id), stickyMarks.chrome(of: id)],
            float: id.raw
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
