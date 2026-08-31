import KiwiDeskCore
import SwiftUI

/// Header bar identity component and titlebar clearance.
extension SettingsHeaderBar {
    /// Inset clearing macOS window control traffic lights.
    static let trafficLightInset: CGFloat = 84

    /// Home identity view with app mark and localized title.
    var identity: some View {
        HStack(spacing: 8) {
            if let mark = BrandAssets.appMark {
                Image(nsImage: mark)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
            }
            Text(L("home.title", "Settings"))
                .font(.title2.weight(.bold))
                .foregroundStyle(SettingsTheme.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L("home.title_ax", "KiwiDesk Settings")
        )
    }
}
