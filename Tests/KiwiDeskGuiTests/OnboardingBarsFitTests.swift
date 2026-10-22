import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The tour window is a fixed 560 × 620 (#828), and every copy
/// tier wraps rather than truncates, so a page that grows past it
/// pushes its Continue button out of the window. The bars step
/// (#2515) and the keys step it grew by two rows are measured in
/// every shipped catalog, over the seeded keymap with five Spaces.
///
/// Spends: one AppKit layout pass per page per catalog on the
/// main actor, about a dozen catalogs.
@Suite("Onboarding pages fit the tour window (#2515)")
@MainActor
struct OnboardingBarsFitTests {
    /// The window's height less its vertical padding, the progress
    /// row and the stack spacing under it (`OnboardingView`).
    private static let budget: CGFloat = 620 - 2 * 26 - 5 - 16
    /// The window's width less its horizontal padding.
    private static let width: CGFloat = 560 - 2 * 30

    private static var seeded: KeyLayer {
        var layer = KeyLayer.defaultLayer
        layer.bindings = DefaultKeybindings.bindings(
            spaces: spaces,
            resizeStep: 50,
            base: .standard
        )
        return layer
    }

    private static let spaces = (1...5).map { SpaceID($0) }

    private func model() -> OnboardingModel {
        let model = OnboardingModel()
        let layer = Self.seeded
        model.keyFamilies = {
            OnboardingKeys.families(layer: layer, spaces: Self.spaces)
        }
        model.bars.revealKeys = {
            OnboardingKeys.revealFamilies(layer: layer)
        }
        model.bars.settingsDraftPending = { true }
        model.beginPresentation(at: .bars)
        return model
    }

    private func height(_ view: some View) -> CGFloat {
        NSHostingView(
            rootView: view.frame(width: Self.width)
                .environmentObject(LocalizationManager.shared)
        ).fittingSize.height
    }

    @Test("the bars and keys pages fit in every catalog")
    func pagesFit() {
        defer { LocalizationManager.shared.select("en") }
        let locales = ["en"] + LocalizationManager.shared.available
        #expect(locales.count > 5, "too few catalogs measured")
        for locale in locales {
            LocalizationManager.shared.select(locale)
            let model = model()
            let bars = height(OnboardingBarsStep(model: model))
            #expect(bars <= Self.budget, "bars page, \(locale): \(bars)")
            let keys = height(KeysPage(model: model))
            #expect(keys <= Self.budget, "keys page, \(locale): \(keys)")
        }
    }

    /// The keys step alone, outside the root view's fixed frame.
    private struct KeysPage: View {
        let model: OnboardingModel

        var body: some View {
            OnboardingView(model: model).keys
        }
    }
}
