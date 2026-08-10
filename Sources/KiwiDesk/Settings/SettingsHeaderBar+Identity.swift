import KiwiDeskCore
import SwiftUI

/// The header bar's Home identity and titlebar clearance — its
/// own file for the §2.1 ceiling, not for reuse.
extension SettingsHeaderBar {
    /// 100 − the bar's own 16 pt gutter.
    ///
    /// The third light's trailing edge falls at about 78 pt on a
    /// standard macOS titlebar (observed 2026-08-04, macOS 26),
    /// and starting the row THERE is what the first cut did: the
    /// app mark ended up 4 pt from the green button, touching it.
    /// 100 buys the mark the same air the prototype gives it.
    /// Neither number is published by any API, so this is a look
    /// constant like the top padding beside it and breaks the
    /// same silent way if Apple moves the buttons.
    static let trafficLightInset: CGFloat = 84

    /// Home's identity: the mark beside "Settings" — decorative
    /// pair, one accessibility element.
    ///
    /// 26 pt, over the §3 inventory's 22: the mark is the app's
    /// one piece of identity on this screen and read as
    /// undersized against the taller bar (owner, 2026-08-04).
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
