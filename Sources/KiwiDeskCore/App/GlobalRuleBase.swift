import Foundation

/// Global window-rule bases captured from the active config owner
/// before any profile sparse diff is applied. Required for
/// Lua-managed profiles: live state holds the effective rules and
/// therefore cannot serve as the next profile's base.
struct GlobalRuleBase {
    var appRules: [String: SpaceID] = [:]
    var floatRules: [String] = []
    var ignoreRules: [String] = []
}
