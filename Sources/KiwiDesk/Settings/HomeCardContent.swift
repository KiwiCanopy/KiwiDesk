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
        let settings = model.homeSettings
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
            let spaceShown = settings.spaceBarStyle.visibility.showsUnprompted
            let edge = edgeName(
                spaceShown
                    ? settings.spaceBarStyle.edge : settings.appBarStyle.edge
            )
            if settings.bothBarsCanShow, settings.sharedBarEdge == nil {
                return L(
                    "home.card.bars.split_subtitle",
                    "Space Bar: %1$@ · App Bar: %2$@",
                    edgeName(settings.spaceBarStyle.edge),
                    edgeName(settings.appBarStyle.edge)
                )
            }
            if spaceShown {
                return L(
                    "home.card.bars.shelf_subtitle",
                    "KiwiShelf · %1$@",
                    edge
                )
            }
            return L(
                "home.card.bars.shelf_subtitle_space_hidden",
                "KiwiShelf · %1$@ · Space Bar hidden",
                edge
            )
        case .looks:
            if settings.animations.anyEnabled {
                return L(
                    "home.card.colors.subtitle",
                    "Animations on · %1$d ms",
                    settings.animations.durationMS
                )
            }
            return L(
                "home.card.colors.subtitle_window_off",
                "Window animations off"
            )
        case .layoutDefaults:
            return Self.layoutSubtitle(settings)
        case .screens:
            return L(
                "home.card.monitors.subtitle",
                "%1$d connected · %2$d Spaces pinned",
                model.displays.count,
                model.config.spacePins.count
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
                where: \.isUsableDefault
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
        case .kiwiVision:
            return kiwiVisionSubtitle(model)
        case .ai:
            // Fixed: KiwiDesk cannot know what an AI app has
            // configured, and a status line is ruled out (#1685).
            return L(
                "home.card.ai.subtitle",
                "Set up and control KiwiDesk with your own AI app"
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
        case .macChecklist:
            return MacChecklistText.cardProgress(
                done: model.macChecklistDone,
                total: MacChecklistProgress.total
            )
        }
    }

    /// Formats actionable shortcut conflict count badge
    /// (`KeybindingConflicts`, #1094/#1105).
    static func conflictShout(
        for destination: SettingsDestination,
        model: SettingsModel
    ) -> String? {
        guard destination == .shortcuts else { return nil }
        let count = model.actionableConflicts().count
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
                && SettingsDraftDiff.namesModelPath($0.id)
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
    /// True when any window animation is enabled.
    var anyEnabled: Bool {
        onWindowResize || onWindowSwap || onRelayout
    }
}

extension HomeCardContent {
    /// The running state, so the card is worth reading (#2103):
    /// off with the chord that turns it on, or on with its values.
    @MainActor static func kiwiVisionSubtitle(
        _ model: SettingsModel
    ) -> String {
        guard model.core.kiwiVisionIsOn else {
            guard
                let chord = ShortcutsOpenBinding.comboGlyphs(
                    core: model.core,
                    lua: KeybindingCatalog.toggleKiwiVision.lua
                )
            else {
                return L(
                    "home.card.kiwivision.off_no_shortcut",
                    "Off · no shortcut yet"
                )
            }
            return L(
                "home.card.kiwivision.off",
                "Off · %1$@ turns it on",
                chord
            )
        }
        let dim = SettingsValueReadout.percent(
            model.appWide.visionDim / 100
        )
        // The blur as drawn: Reduce transparency stands it down.
        return model.core.kiwiVisionDrawsBlur
            ? L(
                "home.card.kiwivision.on_blur",
                "On · Dim %1$@, blur on",
                dim
            )
            : L(
                "home.card.kiwivision.on_no_blur",
                "On · Dim %1$@, blur off",
                dim
            )
    }

    /// Layout Standards' line: the minimum window size every layout
    /// shares, or that layouts differ (#2237).
    static func layoutSubtitle(_ settings: TilingSettings) -> String {
        let sizes = settings.minWindowSizes
        guard let width = sizes.shared(.width),
            let height = sizes.shared(.height)
        else {
            return L(
                "home.card.layout.subtitle_mixed",
                "Modes: %1$d · min window size per layout",
                LayoutMode.allCases.count
            )
        }
        return L(
            "home.card.layout.subtitle_size",
            "Modes: %1$d · min window %2$d × %3$d pt",
            LayoutMode.allCases.count,
            Int(width),
            Int(height)
        )
    }

}
