import AppKit

/// KiwiVision (#2103): the focused window stays clear and every
/// screen dims around it. The plate follows the focus ring's
/// triggers — `updateBorders` ends in `updateVision` — so a focus
/// change, a retile and an own key window re-stack it with the
/// ring, and the ring's WindowServer reorder event re-stacks it
/// ahead of the ring.
extension KiwiCore {
    /// The dim until KiwiVision's settings land (#2103 ruling 10).
    static let visionDim: CGFloat = 0.4

    /// Whether KiwiVision is on.
    public var kiwiVisionIsOn: Bool { vision.isOn }

    /// `kiwivision.toggle`: turns KiwiVision on or off.
    public func toggleKiwiVision() {
        setKiwiVision(!vision.isOn)
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
        guard vision.isOn || vision.hasShownPlates else { return }
        vision.sync(visionRequest(), reassert: reassertOrder)
    }

    /// The target's WindowServer reorder event: the plates go back
    /// under it before its ring does (`BorderManager+SkyLight`).
    func visionTargetReordered(_ id: WindowID) {
        vision.restack(below: id.raw)
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
        var screens: [(display: DisplayID, frame: CGRect)] = []
        var standDown: Set<DisplayID> = []
        for screen in ScreenList.all {
            guard let number = screen.screenNumber else { continue }
            let display = DisplayID(number)
            screens.append((display, screen.frame))
            if shelfStandsDown(on: display) { standDown.insert(display) }
        }
        return VisionManager.Request(
            screens: screens,
            target: target,
            below: ring,
            standDown: standDown,
            dim: Self.visionDim
        )
    }
}
