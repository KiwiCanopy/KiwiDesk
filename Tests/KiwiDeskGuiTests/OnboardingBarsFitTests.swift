import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The tour window is a fixed 560 × 660 (#828, #2446), and every copy
/// tier wraps rather than truncates, so a page that grows past it
/// pushes its Continue button out of the window. The bars step
/// (#2515) and the keys step it grew by two rows are measured in
/// every shipped catalog, over the seeded keymap with five Spaces
/// on each shortcut base (#2694).
///
/// Spends: one AppKit layout pass per page per catalog per base on
/// the main actor, about a dozen catalogs.
@Suite("Onboarding pages fit the tour window (#2515)")
@MainActor
struct OnboardingBarsFitTests {
    /// The window's height less its vertical padding, the progress
    /// row and the stack spacing under it (`OnboardingView`).
    private static let budget =
        OnboardingView.size.height - 2 * OnboardingView.inset.height
        - OnboardingProgressRow.pipHeight - OnboardingView.spacing
    /// The window's width less its horizontal padding.
    private static let width =
        OnboardingView.size.width - 2 * OnboardingView.inset.width

    private static func seeded(_ base: ShortcutBase) -> KeyLayer {
        var layer = KeyLayer.defaultLayer
        layer.bindings = DefaultKeybindings.bindings(
            spaces: spaces,
            resizeStep: 50,
            base: base
        )
        return layer
    }

    private static let spaces = (1...5).map { SpaceID($0) }

    private func model(_ base: ShortcutBase) -> OnboardingModel {
        let model = OnboardingModel()
        let layer = Self.seeded(base)
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

    @Test("the bars and keys pages fit in every catalog and base")
    func pagesFit() {
        defer { LocalizationManager.shared.select("en") }
        let locales = ["en"] + LocalizationManager.shared.available
        #expect(locales.count > 5, "too few catalogs measured")
        for base in ShortcutBase.allCases {
            for locale in locales {
                LocalizationManager.shared.select(locale)
                let model = model(base)
                let at = "\(locale), \(base)"
                let bars = height(OnboardingBarsStep(model: model))
                #expect(bars <= Self.budget, "bars page, \(at): \(bars)")
                let keys = height(KeysPage(model: model))
                #expect(keys <= Self.budget, "keys page, \(at): \(keys)")
            }
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
