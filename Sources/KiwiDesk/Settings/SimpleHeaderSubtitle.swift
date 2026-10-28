import KiwiDeskCore

/// Simple's header subtitle (#2737 ruling 2), from plain values so
/// `SimpleRootTests` drives it without a model: the screen
/// count, then what Simple hides that the user made. Each clause
/// is absent at zero.
@MainActor enum SimpleHeaderSubtitle {
    /// The screen count, or nil with no screen reported.
    static func screens(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return count == 1
            ? L("simple.header.screens_one", "1 screen")
            : L("simple.header.screens", "%1$d screens", count)
    }

    /// The hidden things, joined, or nil when there are none.
    static func hidden(_ counts: SimpleHiddenCounts) -> String? {
        let parts = [
            clause(
                counts.appRules,
                one: L("simple.header.app_rules_one", "1 App Rule"),
                many: { L("simple.header.app_rules", "%1$d App Rules", $0) }
            ),
            clause(
                counts.layers,
                one: L("simple.header.layers_one", "1 shortcut layer"),
                many: {
                    L("simple.header.layers", "%1$d shortcut layers", $0)
                }
            ),
            clause(
                counts.luaBindings,
                one: L("simple.header.lua_one", "1 Lua binding"),
                many: {
                    L("simple.header.lua", "%1$d Lua bindings", $0)
                }
            ),
        ].compactMap { $0 }
        return parts.isEmpty ? nil : join(parts)
    }

    /// The whole line, the hidden clause's link drawn at
    /// `CrossReferenceRow.linkSlot`; nil when nothing is left.
    static func line(
        screenCount: Int,
        hidden counts: SimpleHiddenCounts
    ) -> String? {
        guard let hidden = hidden(counts) else {
            return screens(screenCount)
        }
        let kept = L(
            "simple.header.kept",
            "%1$@, kept in %2$@",
            hidden,
            CrossReferenceRow.linkSlot
        )
        guard let screens = screens(screenCount) else { return kept }
        return join([screens, kept])
    }

    private static func clause(
        _ count: Int,
        one: String,
        many: (Int) -> String
    ) -> String? {
        switch count {
        case ...0: nil
        case 1: one
        default: many(count)
        }
    }

    /// A structural separator, not copy (TRANSLATION_BRIEF rule 3).
    private static func join(_ parts: [String]) -> String {
        parts.joined(separator: " · ")
    }
}
