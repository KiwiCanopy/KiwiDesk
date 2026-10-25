import Foundation

/// Telling left and right modifiers apart (#2601): the switch is
/// `appWide.modifierSides` alone, and the keybinding manager runs
/// the one keyboard tap from it.
extension KiwiCore {
    /// `set_modifier_sides <true|false>`: the running value, as
    /// every app-wide verb (#1741); the Settings row stores it
    /// (`modifier.sides`).
    func setModifierSides(_ args: [JSONValue]) -> CommandResponse {
        guard let on = args.first?.boolValue else {
            return .fail("expected a boolean")
        }
        setAppWide(persisting: false) { $0.modifierSides = on }
        return .ok()
    }
}
