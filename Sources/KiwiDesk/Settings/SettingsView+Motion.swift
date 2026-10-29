import SwiftUI

/// The shell's transitions (#2737 ruling 13). They play only under
/// the root switch's spring; Home to a page and back swaps at once.
/// A transition's own timing names the Reduce Motion gate in its
/// argument.
extension SettingsView {
    /// Simple fades: out ahead of Home's cards, in behind them.
    var simpleTransition: AnyTransition {
        .opacity.animation(
            reduceMotion ? nil : .easeOut(duration: ShellMotion.simpleFade)
        )
    }

    /// Home arrives card by card (`HomeConverge`) and leaves receding
    /// under Simple fading in.
    var homeTransition: AnyTransition {
        .asymmetric(
            insertion: .identity,
            removal: .modifier(
                active: ShellRecede(active: true),
                identity: ShellRecede(active: false)
            )
        )
    }

    /// A page fades, as when a link from Simple lands on it.
    var pageTransition: AnyTransition { .opacity }
}
