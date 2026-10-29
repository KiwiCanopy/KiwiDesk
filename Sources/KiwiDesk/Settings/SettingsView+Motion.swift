import SwiftUI

/// The shell's transitions (#2737 ruling 13). They play only under
/// the root switch's spring; Home to a page and back swaps at once.
/// A transition's own timing names the Reduce Motion gate in its
/// argument.
extension SettingsView {
    /// Simple's sections arrive card by card under a switch, as
    /// Home's do (`HomeConverge`, #2777), and otherwise fade in; it
    /// always leaves fading, ahead of Home's cards.
    var simpleTransition: AnyTransition {
        let fade = AnyTransition.opacity.animation(
            reduceMotion ? nil : .easeOut(duration: ShellMotion.simpleFade)
        )
        return .asymmetric(
            insertion: model.nav.convergePending ? .identity : fade,
            removal: fade
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
