import KiwiDeskCore

/// Localized text for a starter setup's title (#1662): Core names
/// the main screen's class, the GUI narrates it.
extension StarterTitle {
    /// "Ultrawide", or "Widescreen + 1" across several screens.
    @MainActor var displayName: String {
        let shapeName = Self.displayName(of: shape)
        guard otherScreens > 0 else { return shapeName }
        return L(
            "presets.starter.title.more_screens",
            "%1$@ + %2$@",
            shapeName,
            String(otherScreens)
        )
    }

    /// The class name a starter is titled with.
    @MainActor static func displayName(of shape: ScreenClass) -> String {
        switch shape {
        case .laptop:
            L("presets.starter.shape.laptop", "Laptop")
        case .desktop:
            L("presets.starter.shape.widescreen", "Widescreen")
        case .ultrawide:
            L("presets.starter.shape.ultrawide", "Ultrawide")
        case .superUltrawide:
            L(
                "presets.starter.shape.super_ultrawide",
                "Super Ultrawide"
            )
        case .pivoted:
            L("presets.starter.shape.portrait", "Portrait")
        }
    }

    /// The onboarding Spaces page's heading for this setup — one
    /// key per class, since the noun inflects in some locales.
    @MainActor var onboardingTitle: String {
        switch shape {
        case .laptop:
            L(
                "onboarding.starter_spaces.title.laptop",
                "Your Spaces are ready for your laptop"
            )
        case .desktop:
            L(
                "onboarding.starter_spaces.title.widescreen",
                "Your Spaces are ready for your screen"
            )
        case .ultrawide:
            L(
                "onboarding.starter_spaces.title.ultrawide",
                "Your Spaces are ready for your ultrawide"
            )
        case .superUltrawide:
            L(
                "onboarding.starter_spaces.title.super_ultrawide",
                "Your Spaces are ready for your super ultrawide"
            )
        case .pivoted:
            L(
                "onboarding.starter_spaces.title.portrait",
                "Your Spaces are ready for your portrait screen"
            )
        }
    }
}
