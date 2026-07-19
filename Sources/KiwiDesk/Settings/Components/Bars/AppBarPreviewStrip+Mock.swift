import KiwiDeskCore
import SwiftUI

/// The preview's mock content and caption strings, split from
/// the strip's rendering (file-size ceiling). Internal, not
/// private: a same-type extension in another file needs to see
/// them; nothing outside the preview should reach in anyway.
extension AppBarPreviewStrip {
    struct MockTab: Identifiable {
        let id: Int
        let icon: String
        let name: String
        let active: Bool
        let badge: Int?
        /// Stand-in for the app image's own colors, shown only
        /// under the System default icon source (#294).
        let nativeColor: Color
    }

    var mockTabs: [MockTab] {
        [
            MockTab(
                id: 0,
                icon: "globe",
                name: L("app_bar.preview.app_web", "Web"),
                active: false,
                badge: 2,
                nativeColor: .blue
            ),
            MockTab(
                id: 1,
                icon: "envelope",
                name: L("app_bar.preview.app_mail", "Mail"),
                active: true,
                badge: nil,
                nativeColor: .orange
            ),
            MockTab(
                id: 2,
                icon: "terminal",
                name: L("app_bar.preview.app_code", "Code"),
                active: false,
                badge: nil,
                nativeColor: .teal
            ),
        ]
    }

    // MARK: - Caption & accessibility

    var caption: String {
        captionOverride
            ?? L(
                "app_bar.preview.caption",
                "Position: %1$@ · %2$@",
                edgeName,
                styleName
            )
    }

    var axLabel: String {
        L(
            "app_bar.preview.ax",
            "App bar preview: %1$@ position, %2$@ style.",
            edgeName,
            styleName
        )
    }

    private var edgeName: String {
        switch style.edge {
        case .top: return L("app_bar.edge.top", "Top")
        case .bottom: return L("app_bar.edge.bottom", "Bottom")
        case .left: return L("app_bar.edge.left", "Left")
        case .right: return L("app_bar.edge.right", "Right")
        }
    }

    private var styleName: String {
        if style.glassEnabled {
            return L("app_bar.liquid_glass", "Liquid Glass")
        }
        return style.tabBackground == .boxed
            ? L("app_bar.tab_background.boxed", "Boxed")
            : L("app_bar.tab_background.plain", "Plain")
    }
}
