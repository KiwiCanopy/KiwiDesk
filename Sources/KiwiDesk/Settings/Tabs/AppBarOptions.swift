import KiwiDeskCore

/// The shared App Bar option lists so the global editor and the
/// per-layout override pickers stay in sync — one source of the
/// value/label pairs both surfaces render (as segments now, #291).
/// Split out of `AppBarOverrideControls.swift` to keep that file
/// under the line ceiling.
enum AppBarOptions {
    /// Built from `allCases` through an exhaustive switch, so a
    /// new edge case can't silently vanish from the pickers.
    @MainActor
    static let edge: [(AppBarEdge, String)] =
        AppBarEdge.allCases.map { ($0, label($0)) }

    @MainActor
    private static func label(_ edge: AppBarEdge) -> String {
        switch edge {
        case .top: return L("app_bar.edge.top", "Top")
        case .bottom: return L("app_bar.edge.bottom", "Bottom")
        case .left: return L("app_bar.edge.left", "Left")
        case .right: return L("app_bar.edge.right", "Right")
        }
    }
    /// Same exhaustive-switch guard as `edge`.
    @MainActor
    static let alignment: [(AppBarStyle.BarAlignment, String)] =
        AppBarStyle.BarAlignment.allCases.map {
            ($0, label($0))
        }

    @MainActor
    private static func label(
        _ alignment: AppBarStyle.BarAlignment
    ) -> String {
        switch alignment {
        case .start:
            return L("app_bar.alignment.start", "Start")
        case .center:
            return L("app_bar.alignment.center", "Center")
        case .end:
            return L("app_bar.alignment.end", "End")
        }
    }

    /// Liquid Glass (#390) is offered only where it can render —
    /// an OS-capability gate, so the option is absent (not greyed)
    /// below macOS 26. The stored value still round-trips there.
    @MainActor
    static var tabBackground: [(AppBarStyle.TabBackground, String)] {
        var options: [(AppBarStyle.TabBackground, String)] = [
            (.boxed, L("app_bar.tab_background.boxed", "Boxed")),
            (.plain, L("app_bar.tab_background.plain", "Plain")),
        ]
        if AppBarStyle.TabBackground.glassAvailable {
            options.append(
                (
                    .material,
                    L(
                        "app_bar.tab_background.material",
                        "Liquid Glass"
                    )
                )
            )
        }
        return options
    }
    @MainActor
    static let activeIndicator: [(AppBarStyle.ActiveIndicator, String)] = [
        (.ring, L("app_bar.active_indicator.ring", "Ring")),
        (
            .edgeMark,
            L(
                "app_bar.active_indicator.edge_mark",
                "Edge mark"
            )
        ),
        (.gap, L("app_bar.active_indicator.gap", "Gap")),
    ]
    /// #294 icon rendering. "System default" = the icon as
    /// macOS hands it out (the system-wide Icon & widget
    /// style already covers tinting wants); styled variants
    /// are not obtainable via public API (#362).
    @MainActor
    static let iconSource: [(BarAppIconSource, String)] = [
        (
            .appImage,
            L("app_bar.icon_source.app_image", "System default")
        ),
        (
            .appFont,
            L("app_bar.icon_source.app_font", "Glyphs")
        ),
    ]
    @MainActor
    static let content: [(AppBarStyle.Content, String)] = [
        (.icon, L("app_bar.content.icon", "Icon")),
        (.name, L("app_bar.content.name", "Name")),
        (
            .iconAndName,
            L("app_bar.content.icon_and_name", "Icon & name")
        ),
    ]
}
