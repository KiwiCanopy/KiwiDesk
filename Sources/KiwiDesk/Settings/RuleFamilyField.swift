import KiwiDeskCore

/// Where each rule family lives in the draft (#1393): the one list a
/// dropped rule half restores, a landed one adopts, and a reverted
/// row settles its reach against (#792).
@MainActor
struct RuleFamilyField {
    let family: RuleFamily
    /// Copies the family's fields from `source` into `target`.
    let copy: (inout GuiConfig, GuiConfig) -> Void
    /// Whether two configs hold the same rules for the family.
    let same: (GuiConfig, GuiConfig) -> Bool

    static let all: [RuleFamilyField] = [
        field(.space, \.appRules),
        field(.float, \.floatRules),
        // The Desktop base is drafted beside the layers it moves
        // (#1870): never kept or dropped without them.
        RuleFamilyField(
            family: .key,
            copy: {
                $0.layers = $1.layers
                $0.desktopShortcutBase = $1.desktopShortcutBase
            },
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
        _ path: WritableKeyPath<GuiConfig, V>
    ) -> RuleFamilyField {
        RuleFamilyField(
            family: family,
            copy: { $0[keyPath: path] = $1[keyPath: path] },
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
