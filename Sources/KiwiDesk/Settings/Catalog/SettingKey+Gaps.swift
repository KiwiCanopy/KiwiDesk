/// Gaps (`Gaps`, outer/inner + per-space override).

enum GapsKey: String, CaseIterable, Hashable {
    case outerTop = "settings.gapsGlobal.outer.top"
    case outerBottom = "settings.gapsGlobal.outer.bottom"
    case outerLeft = "settings.gapsGlobal.outer.left"
    case outerRight = "settings.gapsGlobal.outer.right"
    case innerHorizontal = "settings.gapsGlobal.inner.horizontal"
    case innerVertical = "settings.gapsGlobal.inner.vertical"
    case outer = "settings.gapsGlobal.outer (master)"
    case inner = "settings.gapsGlobal.inner (master)"
    case perSpaceOverride = "settings.gapsOverride[space]"
}

extension GapsKey {
    var placement: SettingPlacement {
        switch self {
        case .outerTop, .outerBottom, .outerLeft, .outerRight,
            .innerHorizontal, .innerVertical:
            return .row(.gapsAndBorders, .gaps, .showMore)
        case .outer, .inner:
            // The unified slider reads "mixed" while its
            // per-edge values differ (GapsEditor).
            return .row(
                .gapsAndBorders,
                .gaps,
                .atRest,
                gate: .runtime(.perEdgeValuesDiffer)
            )
        case .perSpaceOverride:
            return .luaOnly
        }
    }
}

extension GapsKey {
    var text: SettingRowText {
        switch self {
        case .outerTop:
            return .text("gaps.top")
        case .outerBottom:
            return .text("gaps.bottom")
        case .outerLeft:
            return .text("gaps.left")
        case .outerRight:
            return .text("gaps.right")
        case .innerHorizontal:
            return .text("gaps.horizontal")
        case .innerVertical:
            return .text("gaps.vertical")
        case .outer:
            return .text("gaps.outer")
        case .inner:
            return .text("gaps.inner")
        case .perSpaceOverride:
            return .none
        }
    }
}
