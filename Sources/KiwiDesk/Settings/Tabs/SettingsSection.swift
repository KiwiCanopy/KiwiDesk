import SwiftUI

/// A titled group used across the dashboard sections. The
/// optional symbol puts a glyph before the title — used by the
/// per-mode sections so a layout's glyph (§6.3) travels with
/// its name. The optional caption is a one-sentence plain-words
/// explanation under the title; `subsection` shrinks the title
/// for groups that belong to a bigger one (Ghost / Drop zone
/// under Drag & Drop).
struct SettingsSection<Content: View>: View {
    let title: String
    let symbol: String?
    let caption: String?
    let subsection: Bool
    @ViewBuilder let content: Content

    init(
        _ title: String,
        symbol: String? = nil,
        caption: String? = nil,
        subsection: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        self.caption = caption
        self.subsection = subsection
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let symbol {
                        Image(systemName: symbol)
                            .foregroundStyle(.secondary)
                    }
                    Text(title)
                }
                .font(
                    subsection
                        ? .subheadline.weight(.semibold)
                        : .headline
                )
                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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
