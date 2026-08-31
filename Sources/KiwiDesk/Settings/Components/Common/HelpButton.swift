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
    /// The transient popover already dismisses on this very
    /// click's mouse-down; without the stamp the mouse-up action
    /// would immediately reopen it — the button unable to ever
    /// close its own popover.
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
        // A short action hint, not the content: `.help` already
        // exposes the full text, and duplicating it here would
        // announce it twice per focus pass.
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
