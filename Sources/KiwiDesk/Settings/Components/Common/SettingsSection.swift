import SwiftUI

/// The heading over a run of related sections (the App Bar
/// block in Appearance): the one registered level above a
/// section's `.headline`, so multi-section groups don't each
/// invent their own title style.
struct SettingsGroupHeader: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.title3)
            .fontWeight(.semibold)
    }
}

/// A titled group used across the dashboard sections. The
/// optional symbol puts a glyph before the title — used by the
/// per-mode sections so a layout's glyph (§6.3) travels with
/// its name. The optional caption is a one-sentence plain-words
/// explanation under the title; `subsection` shrinks the title
/// for groups that belong to a bigger one (Ghost / Drop zone
/// under Drag & drop).
///
/// The optional `help` renders a live `HelpButton` beside the
/// title — the block-gate anchor (#527): the header sits
/// OUTSIDE any `GreyOut` in `content`, so while a gate dims the
/// body (killing every `?` inside it, since `.disabled` is
/// cumulative), this one stays clickable and explains why the
/// block is off and how to enable it. Call sites pass it only
/// while their gate is active — once the block is live, its own
/// controls' help takes over and the anchor would gloss nothing.
struct SettingsSection<Content: View>: View {
    let title: String
    let symbol: String?
    let caption: String?
    let subsection: Bool
    let help: String?
    @ViewBuilder let content: Content

    init(
        _ title: String,
        symbol: String? = nil,
        caption: String? = nil,
        subsection: Bool = false,
        help: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        self.caption = caption
        self.subsection = subsection
        self.help = help
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
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
                    if let help {
                        HelpButton(
                            explanation: help,
                            subject: title
                        )
                    }
                }
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
