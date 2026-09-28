import KiwiDeskCore

/// What a tour row's animation shows, spoken (#1750): VoiceOver
/// hears the behaviour a sighted reader watches, since motion is
/// never announced.
enum OnboardingLayoutBehaviour {
    @MainActor static func of(_ mode: LayoutMode) -> String {
        switch mode {
        case .bsp:
            return L(
                "onboarding.starter_spaces.behaviour.bsp",
                "A new window splits the one it lands on."
            )
        case .stack:
            return L(
                "onboarding.starter_spaces.behaviour.stack",
                "One master window; new windows join the stack "
                    + "beside it."
            )
        case .grid:
            return L(
                "onboarding.starter_spaces.behaviour.grid",
                "Windows share a grid that rebalances as they "
                    + "open."
            )
        case .track:
            return L(
                "onboarding.starter_spaces.behaviour.track",
                "Windows line up in tracks, and a new one can "
                    + "start a track of its own."
            )
        case .scrolling:
            return L(
                "onboarding.starter_spaces.behaviour.scrolling",
                "Windows sit in a row, and the view scrolls to "
                    + "follow focus."
            )
        case .monocle:
            return L(
                "onboarding.starter_spaces.behaviour.monocle",
                "One window fills the screen, and focus flips to "
                    + "the next one."
            )
        case .floating:
            return L(
                "onboarding.starter_spaces.behaviour.floating",
                "Windows stay wherever you put them."
            )
        }
    }
}
