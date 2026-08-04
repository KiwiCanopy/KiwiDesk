import KiwiDeskCore
import SwiftUI

extension SettingsView {
    /// The pushed area's pane. Split out of `SettingsView` when
    /// the shell's theme wiring took that file past the §2.1
    /// ceiling — pure routing, and the one place the twelve areas
    /// are named, so it is the part that reads best alone.
    ///
    /// Takes the destination rather than reading `selection`: that
    /// property is `private`, and an extension in a second file
    /// cannot see it. Passing it also makes the pane a function of
    /// its argument, which is what it always was.
    @ViewBuilder func detail(
        _ selection: SettingsDestination?
    ) -> some View {
        switch selection {
        // nil is Home, which mounts instead of this pane —
        // unreachable here, but the switch must be total.
        case nil:
            EmptyView()
        case .spaces:
            SpacesSection(model: model)
        case .layoutDefaults:
            LayoutDefaultsSection(model: model)
        case .monitors:
            MonitorsSection(model: model)
        case .colors:
            ColorsMotionSection(model: model)
        case .advancedColors:
            AdvancedColorsSection(model: model)
        case .gapsAndBorders:
            GapsAndBordersSection(model: model)
        case .bars:
            BarsSection(model: model)
        case .behavior:
            BehaviorSection(model: model)
        case .profiles:
            ProfilesSection(model: model)
        case .shortcuts:
            ShortcutsSection(model: model)
        case .appRules:
            AppRulesSection(model: model)
        case .general:
            GeneralSection(model: model)
        }
    }
}
