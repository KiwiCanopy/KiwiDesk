import Foundation
import KiwiDeskCore

/// The `app_rules` tool (#1685 ▸ Ruling 2, 6c): the `app_rule.*`
/// verbs as one tool, built by `groupTool`.
extension MCPTools {
    static let appRules = "app_rules"

    /// The command group the tool wraps.
    static let appRuleGroup = "app_rule"

    static let appRulesSpec = GroupToolSpec(
        name: appRules,
        group: appRuleGroup,
        title: "Set up KiwiDesk app rules",
        lead: "Lists and changes app rules: which Space an app's new "
            + "windows open in, and which windows float. app is the "
            + "bundle_id \(getState) lists for the app's windows."
    )
}
