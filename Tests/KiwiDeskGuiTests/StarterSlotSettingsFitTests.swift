import CoreGraphics
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The starter Scrolling slot is sized so KiwiDesk's own Settings
/// window, tiled right after onboarding, keeps its preview column
/// (#1662). Derived from both constants, so retuning either side
/// re-asks the question rather than restating an answer.
@Suite("Starter slot fits the Settings preview")
struct StarterSlotSettingsFitTests {
    /// A 14" MacBook Pro — the narrowest screen the ruling names —
    /// and the 1080p screen that is the Widescreen class's floor.
    @Test("a starter slot keeps the Settings preview docked")
    func slotFitsPreview() {
        for (shape, width) in [
            (ScreenClass.laptop, CGFloat(1728)),
            (ScreenClass.desktop, CGFloat(1920)),
        ] {
            let settings = StarterTuning.settings(mainShape: shape)
            let gap: CGFloat = shape == .laptop ? 6 : 8
            #expect(settings.gapsGlobal == .uniform(gap))
            let slot = settings.scrolling.slotSize.resolved(
                along: width - 2 * gap,
                gap: gap,
                horizontal: true
            )
            #expect(
                slot >= SettingsWidthClass.panelBreakpoint,
                "\(shape): \(slot) pt"
            )
        }
    }
}
