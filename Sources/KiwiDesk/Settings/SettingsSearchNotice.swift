import SwiftUI

/// The one-line, self-clearing confirmation shown after a
/// search pick flipped the window into Power User mode (#678
/// 4c). The flip itself is silent (`ensureModeAdmits`); this
/// strip is the one place the mode is mentioned, so it stays a
/// sentence — no controls, no second line, no persistence.
struct SettingsSearchNotice: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(SettingsTheme.ink)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(
                    cornerRadius: SettingsTheme.cardRadius
                )
                .fill(
                    SettingsTheme.accent.opacity(
                        SettingsTheme.searchNoticeFillOpacity
                    )
                )
            )
    }
}
