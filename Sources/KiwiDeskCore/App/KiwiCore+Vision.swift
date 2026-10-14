import AppKit

/// KiwiVision (#2103): the focused window stays clear and every
/// screen dims around it. The plate follows the focus ring's
/// triggers — `updateBorders` ends in `updateVision` — so a focus
/// change, a retile and an own key window re-stack it with the
/// ring, and the target's WindowServer reorder event re-stacks it
/// once the ring has re-ordered (borders.md ▸ KiwiVision).
extension KiwiCore {
    /// Whether KiwiVision is on.
    public var kiwiVisionIsOn: Bool { vision.isOn }

    /// `kiwivision.toggle`: turns KiwiVision on or off.
    public func toggleKiwiVision() {
        setKiwiVision(!vision.isOn)
    }

    /// The `kiwivision.*` verbs (#2103). Dim and blur are session
    /// values until KiwiVision's settings are stored; no window
    /// moves, so no retile.
    func visionCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "kiwivision.toggle":
            toggleKiwiVision()
            return .ok(.object(["on": .bool(kiwiVisionIsOn)]))
        case "kiwivision.set_dim":
            // Lua's whole range, as the GUI's (ruling 10, amended).
            guard let percent = args.first?.numberValue,
                percent.isFinite, (0...100).contains(percent)
            else { return .fail("expected 0-100") }
            vision.dim = CGFloat(percent / 100)
        case "kiwivision.set_blur":
            guard let on = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            vision.blur = on
        default:
            return .fail("unknown command: \(command)")
        }
        updateVision()
        return .ok()
    }

    func setKiwiVision(_ on: Bool) {
        guard on != vision.isOn else { return }
        vision.isOn = on
        updateVision(reassertOrder: true)
        vision.onChange(on)
    }

    /// Re-draws the plates from the live focus. Costs nothing
    /// while the mode is off and every plate has faded.
    func updateVision(reassertOrder: Bool = false) {
        guard
            vision.isOn || vision.hasShownPlates
                || !borders.visionTracked.isEmpty
        else { return }
        var request = visionRequest()
        // Watched whether or not a ring or a mark asks (#2103).
        borders.setVisionTracked(
            vision.isOn
                ? Set(request.target.map { [WindowID($0)] } ?? []) : []
        )
        request.tracked = borders.skyLightActive
        vision.sync(request, reassert: reassertOrder)
    }

    /// The target's WindowServer reorder event, after its ring's
    /// re-order (`BorderManager+SkyLight`).
    func visionTargetRestacked(_ id: WindowID) {
        vision.restack(after: id.raw)
    }

    /// The shelf's stand-down verdict, judged once per pass in
    /// `updateBars`; a change re-draws the plates.
    func noteVisionStandDown(_ displays: Set<DisplayID>) {
        if vision.noteStandDown(displays) { updateVision() }
    }

    /// What the plates draw now. The window kept clear is the
    /// ring's focused window, or an own key window that is not it
    /// — a dialog, Sparkle's alert — which stays clear the way
    /// it stands the focused ring down (#933).
    func visionRequest() -> VisionManager.Request {
        let anchor = activeSpace.flatMap {
            state.focusAnchor(
                of: $0,
                tiled: state.effectiveTiledMembers(of: $0)
            )
        }
        let ownKey = eventLoop.ownKeyWindow()
            .flatMap { UInt32(exactly: $0.number) }
            .flatMap { $0 == anchor?.raw ? nil : $0 }
        let target = ownKey ?? anchor?.raw
        let ring =
            ownKey == nil
            ? anchor.flatMap { borders.ringPanel(of: $0) } : nil
        let screens = ScreenList.all.compactMap { screen in
            screen.screenNumber.map { (DisplayID($0), screen.frame) }
        }
        return VisionManager.Request(
            screens: screens,
            target: target,
            below: ring,
            standDown: vision.standDown,
            tracked: borders.skyLightActive,
            dim: vision.dim,
            // Reduce transparency stands the blur down; the dim
            // stays (#2103, design-decisions ▸ Reduce transparency).
            blur: vision.blur && !LiquidGlassGate.reducesTransparency
        )
    }
}
