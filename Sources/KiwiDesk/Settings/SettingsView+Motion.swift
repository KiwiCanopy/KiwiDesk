import SwiftUI

/// The shell's transitions (#2737 ruling 13). Only an INSERTION reads
/// `nav.shellMotion`: a leaving branch plays the transition it carried
/// at its last render, before the change recorded its cause, so each
/// removal is one fixed motion. The spring is gated where the shell
/// keys it; a transition's own timing names the gate in its argument.
extension SettingsView {
    /// Simple's sections arrive card by card under a switch, as
    /// Home's do (`HomeConverge`, #2777), and otherwise fade in; it
    /// always leaves fading, ahead of Home's cards.
    var simpleTransition: AnyTransition {
        let fade = AnyTransition.opacity.animation(
            reduceMotion ? nil : .easeOut(duration: ShellMotion.simpleFade)
        )
        return .asymmetric(
            insertion: model.nav.shellMotion == .converge
                ? .identity : fade,
            removal: fade
        )
    }

    /// Home arrives card by card under a switch (`HomeConverge`),
    /// otherwise fades in; it always leaves receding — under a page
    /// growing over it, or under Simple fading in.
    var homeTransition: AnyTransition {
        .asymmetric(
            insertion: model.nav.shellMotion == .converge
                ? .identity : .opacity,
            removal: .modifier(
                active: ShellRecede(active: true),
                identity: ShellRecede(active: false)
            )
        )
    }

    /// A card's page grows out of the card's box, its content fading
    /// in last (`PageContentLag`); any other landing zooms through. A
    /// page leaves fading, its box folding back into the card.
    var pageTransition: AnyTransition {
        let insertion: AnyTransition =
            pageExpands
            ? .identity
            : .scale(scale: 0.96).combined(with: .opacity)
        return .asymmetric(insertion: insertion, removal: .opacity)
    }

    /// Whether the page on screen grew out of the card that opened it.
    var pageExpands: Bool {
        guard let destination = model.destination else { return false }
        return model.nav.shellMotion == .expand(destination)
    }
}
