extension TilingSettings {
    /// Whether KiwiHub, the cue plates and the Space-switch slide
    /// plates wear the Fill (#2569): the toggle on and a Fill with a
    /// colour, on glass that draws. `glassDrawn` is the caller's one
    /// read of their leaf as drawn — `LiquidGlassGate.rendered(glass:)`
    /// in Core, `PanelGlass` under the live Reduce transparency in
    /// the GUI — so the decision stays pure.
    public func panelsWearFill(glassDrawn: Bool) -> Bool {
        kiwishelf.tintHubAndPlates && kiwishelf.hasFill && glassDrawn
    }
}
