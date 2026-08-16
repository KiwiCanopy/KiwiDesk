import KiwiDeskCore

/// The shared App Bar option lists so the global editor and the
/// per-layout override pickers stay in sync — one source of the
/// value/label pairs both surfaces render (as segments now, #291).
/// Split out of the per-space override chrome
/// (`SpaceOverrides/OverrideControls.swift`) to keep that file
/// under the line ceiling. It stays here because these ARE bar
/// data — the edges and alignments the App Bar editor renders —
/// while the chrome that once wrapped them moved to the one
/// surface that still draws it (#819).
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

    /// WHERE the background is drawn — per item, or one plate
    /// behind all of them. Liquid Glass is no longer an option
    /// here — it is a separate `liquidGlass` finish toggle (#390),
    /// offered only where it can render (macOS 26+).
    @MainActor
    static let backgroundStyle: [(AppBarStyle.BackgroundStyle, String)] = [
        (.boxed, L("app_bar.background_style.boxed", "Boxed")),
        (.plain, L("app_bar.background_style.plain", "Plain")),
    ]
    /// How far the shared plate reaches (QA 2026-07-19).
    /// Default (hug) first, like every options list here.
    @MainActor
    static let backgroundFit: [(AppBarStyle.BackgroundFit, String)] = [
        (
            .hug,
            L(
                "app_bar.background_fit.hug",
                "Hug"
            )
        ),
        (
            .full,
            L(
                "app_bar.background_fit.full",
                "Full width"
            )
        ),
    ]
    @MainActor
    static let activeIndicator: [(AppBarStyle.ActiveIndicator, String)] = [
        (.outline, L("app_bar.active_indicator.outline", "Outline")),
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
