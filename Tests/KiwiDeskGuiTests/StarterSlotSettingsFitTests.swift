import CoreGraphics
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The starter Scrolling slot is sized so KiwiDesk's own Settings
/// window, tiled right after onboarding, keeps its preview column
/// (#1662). Derived from both constants and the tuned gaps, so
/// retuning any of them re-asks the question.
@Suite("Starter slot fits the Settings preview")
struct StarterSlotSettingsFitTests {
    /// Default point widths: the 13" MacBook Air — the narrowest
    /// the ruling covers — the 14" MacBook Pro, and a 1080p screen,
    /// the Widescreen class's floor.
    @Test("a starter slot keeps the Settings preview docked")
    func slotFitsPreview() {
        for width: CGFloat in [1470, 1512, 1920] {
            let shape = ScreenClass.of(
                CGSize(width: width, height: width * 0.62)
            )
            let settings = StarterTuning.settings(
                mainShape: shape,
                hosts: [:]
            )
            let gaps = settings.gapsGlobal
            let slot = settings.scrolling.slotSize.resolved(
                along: width - gaps.outer.left - gaps.outer.right,
                gap: gaps.inner.horizontal,
                horizontal: true
            )
            #expect(
                slot >= SettingsWidthClass.panelBreakpoint,
                "\(width) pt (\(shape)): \(slot) pt"
            )
        }
    }
}
