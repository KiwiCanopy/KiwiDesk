import SwiftUI

/// A titled group used across the dashboard sections. The
/// optional symbol puts a glyph before the title — used by the
/// per-mode sections so a layout's glyph (§6.3) travels with
/// its name.
struct SettingsSection<Content: View>: View {
    let title: String
    let symbol: String?
    @ViewBuilder let content: Content

    init(
        _ title: String,
        symbol: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .foregroundStyle(.secondary)
                }
                Text(title)
            }
            .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(12)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        Color(
                            nsColor: .controlBackgroundColor
                        )
                    )
            )
        }
    }
}
