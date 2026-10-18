import KiwiDeskCore

/// Where each rule family lives in the draft (#1393), for a
/// reverted row to settle the family's reach against (#792); held
/// to every family beside `dropRuleHalf` and `adoptRuleHalf` by
/// `RuleReachGuiParityTests`.
@MainActor
struct RuleFamilyField {
    let family: RuleFamily
    /// Whether two configs hold the same rules for the family.
    let same: (GuiConfig, GuiConfig) -> Bool

    static let all: [RuleFamilyField] = [
        field(.space, \.appRules),
        field(.float, \.floatRules),
        // The Desktop base is drafted beside the layers it moves
        // (#1870): never kept or dropped without them.
        RuleFamilyField(
            family: .key,
            same: {
                $0.layers == $1.layers
                    && $0.desktopShortcutBase == $1.desktopShortcutBase
            }
        ),
        field(.scroll, \.scrollGesture),
        field(.history, \.spaceHistory),
        field(.cycle, \.modeCycle),
        field(.tile, \.tileRules),
        field(.autoFloat, \.floatAutomatically),
    ]

    static func of(_ family: RuleFamily) -> RuleFamilyField? {
        all.first { $0.family == family }
    }

    private static func field<V: Equatable>(
        _ family: RuleFamily,
        _ path: KeyPath<GuiConfig, V>
    ) -> RuleFamilyField {
        RuleFamilyField(
            family: family,
            same: { $0[keyPath: path] == $1[keyPath: path] }
        )
    }
}

extension RuleFamily {
    /// The table key a float or Tile rule files its app under: the
    /// rule's app, keyed as the family keys a subject (#2345).
    func subject(ofRule rule: String) -> String {
        key(FloatRules.app(of: rule))
    }
}
