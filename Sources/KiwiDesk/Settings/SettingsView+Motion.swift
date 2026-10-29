import SwiftUI

/// The shell's transitions, one per cause `nav.shellMotion` records
/// (#2737 ruling 13). The spring is gated where the shell keys it;
/// a transition's own timing names the gate in its argument.
extension SettingsView {
    /// Simple fades: out ahead of Home's cards, in behind them.
    var simpleTransition: AnyTransition {
        .opacity.animation(
            reduceMotion ? nil : .easeOut(duration: ShellMotion.simpleFade)
        )
    }

    /// Home under a switch arrives card by card (`HomeConverge`) and
    /// leaves shrinking into the window's centre; under a card's page
    /// it recedes; otherwise it fades.
    var homeTransition: AnyTransition {
        switch model.nav.shellMotion {
        case .converge:
            return .asymmetric(
                insertion: .identity,
                removal: .scale(scale: 0.6).combined(with: .opacity)
            )
        case .expand:
            return .modifier(
                active: ShellRecede(active: true),
                identity: ShellRecede(active: false)
            )
        case .none, .zoomThrough:
            return .opacity
        }
    }

    /// A card's page grows out of the card's box, its content fading
    /// in last; a landing with no card zooms through.
    var pageTransition: AnyTransition {
        switch model.nav.shellMotion {
        case .expand:
            return .opacity.animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: 0.2).delay(ShellMotion.contentLag)
            )
        case .converge, .none, .zoomThrough:
            return .scale(scale: 0.96).combined(with: .opacity)
        }
    }
}
