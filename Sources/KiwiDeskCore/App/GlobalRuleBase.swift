import Foundation

/// Global window-rule bases captured from the active config owner
/// before any profile sparse diff is applied. Required for
/// Lua-managed profiles: live state holds the effective rules and
/// therefore cannot serve as the next profile's base.
struct GlobalRuleBase {
    var appRules: [String: SpaceID] = [:]
    var floatRules: [String] = []
    var ignoreRules: [String] = []
    var tileRules: [String] = []
    /// `float_automatically`'s base (#2173).
    var floatAutomatically = FloatGuess.enabledByDefault
    /// The live profile's `float_automatically` override as last
    /// resolved, so the verb re-resolves without a file read
    /// (profiles.md, #1245). Not a base: a profile apply writes it.
    var liveFloatAutomatically: Bool?

    /// The guess `float_automatically` and the resolved Tile rules
    /// make — built here alone.
    func guess(tileRules: [String]) -> FloatGuess {
        FloatGuess(
            enabled: liveFloatAutomatically ?? floatAutomatically,
            tileRules: tileRules
        )
    }
}
