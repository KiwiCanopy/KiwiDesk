import SwiftUI

/// A sync warning: the warning ink with a triangle beside the text,
/// so it never rests on colour alone (WCAG 1.4.1), as
/// `SpaceNameNoticeCaption` draws its refusal.
struct SyncWarning: View {
    let text: String
    var font: Font = .caption

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .accessibilityHidden(true)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(font)
        .foregroundStyle(SettingsTheme.warningInk)
    }
}
