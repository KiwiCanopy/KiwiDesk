import AppKit
import KiwiDeskCore
import os

/// The Windows side's app strip (#3135): its opener, which puts the
/// strip on the app of the window used last, and its back key.
extension JumpPanelController {
    /// `kiwihub.show_last_app()`: opens Windows with the strip on
    /// the last app, or switches there from another side; pressed
    /// again while Windows is up, it steps to the next app, as ⌘⇥
    /// does, and its chord with ⇧ steps back (`backKey`, #3135,
    /// owner 2026-11-09). Esc closes.
    func toggleLastApp() {
        switch Self.lastAppAction(
            showing: isOpen ? currentModel?.scope : nil
        ) {
        case .open: show(.windows, lastApp: true)
        case .step:
            currentModel?.handle(.side(1), repeated: false)
            currentModel?.latchOpener(NSEvent.modifierFlags)
        case .switchScope:
            currentModel?.setScope(.windows)
            currentModel?.openOnLastApp()
            currentModel?.latchOpener(NSEvent.modifierFlags)
        }
    }

    enum LastAppAction: Equatable { case open, step, switchScope }

    /// Steps where Windows already shows, switches where another
    /// side does, else opens.
    static func lastAppAction(showing: JumpScope?) -> LastAppAction {
        guard let showing else { return .open }
        return showing == .windows ? .step : .switchScope
    }

    /// The strip's back key from the live bindings: the last-app
    /// opener's chord with ⇧ (#3135, owner 2026-11-09).
    static func backKey(_ core: KiwiCore) -> KeyCombo? {
        JumpKey.back(
            of: ShortcutsOpenBinding.combo(
                core: core,
                lua: KiwiHubSide.lastAppLua
            )
        )
    }
}
