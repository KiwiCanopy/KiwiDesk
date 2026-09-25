import KiwiDeskCore

/// Per-layout App Bar override diff row generators (`LayoutAppBar`).
extension SettingsValueReadout {
    static func layoutAppBarRows(
        _ key: LayoutAppBarKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let census = SettingKey.layoutAppBar(key)
        let mode = layoutBarMode(key)
        let o = layoutBar(old, mode)
        let n = layoutBar(new, mode)
        switch key {
        case .monocleAppBarEnabled, .scrollingAppBarEnabled:
            // The one always-present field; the census label is
            // already the layout's own name.
            return [
                .change(
                    census,
                    label: label(for: census),
                    old: onOff(o.enabled),
                    new: onOff(n.enabled)
                )
            ]
        case .monocleAppBarActiveIndicator,
            .scrollingAppBarActiveIndicator:
            return layoutBarRow(
                census,
                mode,
                .appBarActiveIndicator,
                layoutBarChoice(
                    o.activeIndicator,
                    AppBarOptions.activeIndicator
                ),
                layoutBarChoice(
                    n.activeIndicator,
                    AppBarOptions.activeIndicator
                )
            )
        case .monocleAppBarTitleCap, .scrollingAppBarTitleCap:
            return layoutBarRow(
                census,
                mode,
                .appBarTitleCap,
                layoutBarCount(o.titleCap),
                layoutBarCount(n.titleCap)
            )
        case .monocleAppBarContent, .scrollingAppBarContent:
            return layoutBarRow(
                census,
                mode,
                .appBarContent,
                layoutBarChoice(o.content, AppBarOptions.content),
                layoutBarChoice(n.content, AppBarOptions.content)
            )
        case .monocleAppBarGroupAdjacentWindows,
            .scrollingAppBarGroupAdjacentWindows:
            return layoutBarRow(
                census,
                mode,
                .appBarGroupAdjacentWindows,
                layoutBarOnOff(o.groupAdjacentWindows),
                layoutBarOnOff(n.groupAdjacentWindows)
            )
        }
    }

    /// The stored override struct the key narrates.
    private static func layoutBar(
        _ config: GuiConfig,
        _ mode: LayoutMode
    ) -> LayoutAppBar {
        mode == .monocle
            ? config.settings.monocle.appBar
            : config.settings.scrolling.appBar
    }

    /// Which layout a key narrates — explicit, so a third layout
    /// growing a bar cannot silently misroute to Scrolling.
    private static func layoutBarMode(
        _ key: LayoutAppBarKey
    ) -> LayoutMode {
        switch key {
        case .monocleAppBarEnabled, .monocleAppBarActiveIndicator,
            .monocleAppBarContent, .monocleAppBarTitleCap,
            .monocleAppBarGroupAdjacentWindows:
            return .monocle
        case .scrollingAppBarEnabled, .scrollingAppBarActiveIndicator,
            .scrollingAppBarContent, .scrollingAppBarTitleCap,
            .scrollingAppBarGroupAdjacentWindows:
            return .scrolling
        }
    }
}
