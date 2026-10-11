import Foundation

/// The escape for automatic floats (#2173): `float_automatically`
/// and `tile_rules` decide where detection may float a window on a
/// guess. Both resolve with the window rules, through
/// `setResolvedWindowRules`, into `EventLoop.floatRules.guess`.
extension KiwiCore {
    /// `set_float_automatically`: writes the BASE, so a profile's
    /// own override still wins, and lasts until the next config
    /// load.
    func setFloatAutomatically(_ args: [JSONValue]) -> CommandResponse {
        guard let enabled = args.first?.boolValue else {
            return .fail("expected boolean")
        }
        globalRuleBase.floatAutomatically = enabled
        setResolvedWindowRules(WindowRuleOverrides(activeProfileOverrides()))
        return .ok()
    }
}
