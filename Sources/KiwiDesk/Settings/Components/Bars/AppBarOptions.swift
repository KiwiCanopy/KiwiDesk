import KiwiDeskCore

/// Shared App Bar option value/label pairs (#291, #819).
enum AppBarOptions {
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

    /// Background plate drawing style (#390).
    @MainActor
    static let backgroundStyle: [(AppBarStyle.BackgroundStyle, String)] = [
        (.boxed, L("app_bar.background_style.boxed", "Boxed")),
        (.plain, L("app_bar.background_style.plain", "Plain")),
    ]

    /// Background reach options.
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

    /// App icon rendering options (#294, #362).
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

    /// Localized title for a given icon source option.
    @MainActor
    static func iconSourceTitle(_ source: BarAppIconSource) -> String {
        iconSource.first { $0.0 == source }?.1 ?? ""
    }

    @MainActor
    static let content: [(AppBarStyle.Content, String)] = [
        (.icon, L("app_bar.content.icon", "Icon")),
        (.title, L("app_bar.content.title", "Title")),
        (
            .iconAndTitle,
            L("app_bar.content.icon_and_title", "Icon & title")
        ),
    ]
}
