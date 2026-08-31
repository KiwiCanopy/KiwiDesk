import KiwiDeskCore
import SwiftUI

/// Contextual help button opening an explanatory popover (#94).
///
/// Follows standard placement inside `settingsLabelColumn`.
struct HelpButton: View {
    /// Markdown-supported explanation text.
    let explanation: String
    /// Accessible subject label (#251).
    var subject: String? = nil
    @State private var shown = false
    @State private var dismissed = Date.distantPast

    private static let textWidth: CGFloat = 260

    var body: some View {
        Button {
            if Date.now.timeIntervalSince(dismissed) > 0.3 {
                shown = true
            }
        } label: {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .controlSize(.small)
        .hoverHighlight(cornerRadius: 4, padding: 2)
        .popover(isPresented: $shown, arrowEdge: .bottom) {
            Text(rich)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(
                    maxWidth: Self.textWidth,
                    alignment: .leading
                )
                .padding(12)
                .onDisappear { dismissed = .now }
        }
        .help(plain)
        .accessibilityLabel(
            subject.map { L("help.button.for", "Help: %1$@", $0) }
                ?? L("help.button", "Help")
        )
        .accessibilityHint(
            L(
                "help.button.hint",
                "Shows an explanation of this setting."
            )
        )
    }

    /// Markdown-parsed body preserving whitespace formatting.
    private var rich: AttributedString {
        (try? AttributedString(
            markdown: explanation,
            options: .init(
                interpretedSyntax:
                    .inlineOnlyPreservingWhitespace
            )
        )) ?? AttributedString(explanation)
    }

    private var plain: String {
        String(rich.characters)
            .replacingOccurrences(of: "**", with: "")
    }
}
