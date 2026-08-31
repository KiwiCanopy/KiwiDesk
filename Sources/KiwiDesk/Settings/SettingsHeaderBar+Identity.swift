import KiwiDeskCore
import SwiftUI

/// Header bar identity component and titlebar clearance.
extension SettingsHeaderBar {
    /// 100 − the bar's own 16 pt gutter: the third light ends near
    /// 78 pt (observed macOS 26) and starting there touched the
    /// green button. No API publishes this — a look constant that
    /// breaks silently if Apple moves the buttons.
    static let trafficLightInset: CGFloat = 84

    /// Home identity view; the 26 pt mark (over the inventory's
    /// 22) read undersized against the taller bar (owner
    /// 2026-08-04).
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
