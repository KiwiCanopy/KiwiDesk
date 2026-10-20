import SwiftUI

/// The one warning surface Settings draws: a triangle and the
/// sentence in `warningInk` on `warningSurface`, the one fix on the
/// same line. A solid surface, never an opacity wash: a wash takes
/// its result from whatever is behind it and cannot promise 4.5:1
/// for `warningInk`.
struct WarningBox<Accessory: View>: View {
    let text: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SettingsTheme.warningInk)
                .accessibilityHidden(true)
            Text(text)
                .font(.callout)
                .foregroundStyle(SettingsTheme.warningInk)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            accessory
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(SettingsTheme.warningSurface)
        )
    }
}
