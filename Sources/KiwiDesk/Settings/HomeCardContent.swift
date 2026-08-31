import KiwiDeskCore
import SwiftUI

/// Subtitle and readout derivation for Home navigation cards (#678 turn 9).
@MainActor
enum HomeCardContent {
    /// Formats current-value summary line for destination card.
    static func subtitle(
        for destination: SettingsDestination,
        model: SettingsModel
    ) -> String {
        let settings = model.config.settings
        switch destination {
        case .spaces:
            return L(
                "home.card.spaces.subtitle",
                "%1$d Spaces · %2$d layouts in use",
                model.config.spaces.count,
                layoutsInUse(model)
            )
        case .gapsAndBorders:
            let outer = Int(settings.gapsGlobal.outer.top)
            let inner = Int(
                settings.gapsGlobal.inner.horizontal
            )
            if settings.borderStyle.enabled {
                return L(
                    "home.card.gaps.subtitle",
                    "Outer %1$d · inner %2$d · border %3$d pt",
                    outer,
                    inner,
                    Int(settings.borderStyle.width)
                )
            }
            return L(
                "home.card.gaps.subtitle_border_off",
                "Outer %1$d · inner %2$d · border off",
                outer,
                inner
            )
        case .bars:
            let appBarEdge = edgeName(
                settings.appBarStyle.edge
            )
            if settings.spaceBarStyle.enabled {
                return L(
                    "home.card.bars.subtitle",
                    "Space Bar %1$@ · App Bar %2$@",
                    edgeName(settings.spaceBarStyle.edge),
                    appBarEdge
                )
            }
            return L(
                "home.card.bars.subtitle_space_off",
                "Space Bar off · App Bar %1$@",
                appBarEdge
            )
        case .colors:
            if settings.animations.anyEnabled {
                return L(
                    "home.card.colors.subtitle",
                    "Animations on · %1$d ms",
                    settings.animations.durationMS
                )
            }
            return L(
                "home.card.colors.subtitle_off",
                "Animations off"
            )
        case .layoutDefaults:
            return L(
                "home.card.layout.subtitle",
                "%1$d modes · min window %2$d pt",
                LayoutMode.allCases.count,
                Int(settings.minWindowSize)
            )
        case .monitors:
            return L(
                "home.card.monitors.subtitle",
                "%1$d connected · %2$d Spaces pinned",
                model.displays.count,
                model.config.spacePins.count
            )
        case .behavior:
            if settings.mouseResize == .layout {
                return L(
                    "home.card.behavior.subtitle_layout",
                    "Drag resizes neighbours · quit leaves "
                        + "%1$d windows per grid cell",
                    settings.quitGridTargetDepth
                )
            }
            return L(
                "home.card.behavior.subtitle_snap_back",
                "Drag snaps back · quit leaves %1$d windows "
                    + "per grid cell",
                settings.quitGridTargetDepth
            )
        case .advancedColors:
            return L(
                "home.card.advanced_colors.subtitle",
                "%1$d individual colors",
                advancedColourCount
            )
        case .shortcuts:
            return L(
                "home.card.shortcuts.subtitle",
                "%1$d bound",
                boundCount(model)
            )
        case .profiles:
            let summaries = model.profileSummaries
            guard !summaries.isEmpty else {
                return L(
                    "home.card.profiles.none",
                    "No profiles yet — start here"
                )
            }
            if let fallback = summaries.first(
                where: \.isDefault
            ) {
                return L(
                    "home.card.profiles.subtitle",
                    "%1$d saved · %2$@ is default",
                    summaries.count,
                    fallback.name
                )
            }
            return L(
                "home.card.profiles.subtitle_no_default",
                "%1$d saved",
                summaries.count
            )
        case .appRules:
            let rules = ruleCount(model)
            guard rules > 0 else {
                return L(
                    "home.card.app_rules.none",
                    "No rules — every app tiles"
                )
            }
            return L(
                "home.card.app_rules.subtitle",
                "%1$d apps pinned or floating",
                rules
            )
        case .general:
            if model.autoStart.level != .off {
                return L(
                    "home.card.general.subtitle",
                    "%1$@ · starts at login",
                    languageName
                )
            }
            return languageName
        }
    }

    /// Formats actionable shortcut conflict count badge
    /// (`KeybindingConflicts`, #1094).
    static func conflictShout(
        for destination: SettingsDestination,
        model: SettingsModel
    ) -> String? {
        guard destination == .shortcuts else { return nil }
        let count = KeybindingConflicts.actionable(
            in: model.config.layers
        ).count
        guard count > 0 else { return nil }
        guard count > 1 else {
            return L("home.card.conflict_one", "1 conflict")
        }
        return L(
            "home.card.conflict_many",
            "%1$d conflicts",
            count
        )
    }

    /// Distinct layout modes across declared spaces.
    private static func layoutsInUse(
        _ model: SettingsModel
    ) -> Int {
        Set(
            model.config.spaces.map {
                model.config.spaceModes[$0] ?? .bsp
            }
        ).count
    }

    /// Bound shortcuts count on default layer.
    private static func boundCount(
        _ model: SettingsModel
    ) -> Int {
        model.config.layers
            .first { $0.isDefault }?
            .bindings.count ?? 0
    }

    private static func ruleCount(
        _ model: SettingsModel
    ) -> Int {
        model.config.appRules.count
            + model.config.floatRules.count
    }

    /// Census count of individual color settings.
    private static var advancedColourCount: Int {
        SettingKey.allCases.filter {
            $0.placement.area == .advancedColours
                && [.atRest, .showMore].contains(
                    $0.placement.tier
                )
        }.count
    }

    private static func edgeName(_ edge: AppBarEdge) -> String {
        AppBarOptions.edge
            .first { $0.0 == edge }?.1 ?? ""
    }

    /// Native display name for currently effective locale
    /// (`LocaleNativeName`).
    private static var languageName: String {
        LocaleNativeName.name(
            for: LocalizationManager.shared.effectiveLocale
                ?? "en"
        )
    }
}

extension AnimationSettings {
    /// True when any event animation is enabled.
    var anyEnabled: Bool {
        onSpaceChange || onWindowResize || onWindowSwap
            || onRelayout
    }
}
