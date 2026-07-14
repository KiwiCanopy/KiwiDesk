import KiwiDeskCore
import SwiftUI

/// The contextual-help affordance (#94): a small circled `?`
/// trailing a settings row, opening a click popover with a
/// sentence or two of explanation.
///
/// A click popover, not a hover-only tooltip: visible and
/// discoverable, a real focusable button (keyboard and
/// VoiceOver reach it), dismissible and re-readable — the
/// System Settings pattern. `.help` rides along as a cheap
/// hover fallback. Help is optional reading: a row's label and
/// options must stay understandable without ever opening it.
///
/// Placement rule: the `?` sits trailing the row, AFTER the
/// control — never in or before the label column, which would
/// break the shared `settingsLabelColumn` alignment.
struct HelpButton: View {
    /// The explanation. Inline Markdown (`**bold**`) renders in
    /// the popover, so a 2–3-option field folds per-option text
    /// into this one popover (option name bold, one line each)
    /// instead of hanging a `?` off every segment.
    let explanation: String
    @State private var shown = false

    /// Popover text measure — comfortable for 2–4 short lines
    /// without ballooning over the pane.
    private static let textWidth: CGFloat = 260

    var body: some View {
        Button {
            shown.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .controlSize(.small)
        .popover(isPresented: $shown, arrowEdge: .bottom) {
            Text(rich)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(
                    maxWidth: Self.textWidth,
                    alignment: .leading
                )
                .padding(12)
        }
        .help(plain)
        .accessibilityLabel(L("help.button", "Help"))
        .accessibilityHint(plain)
    }

    /// Markdown-parsed body. `inlineOnlyPreservingWhitespace`
    /// keeps the hand-authored newlines between per-option
    /// lines while rendering `**bold**`.
    private var rich: AttributedString {
        (try? AttributedString(
            markdown: explanation,
            options: .init(
                interpretedSyntax:
                    .inlineOnlyPreservingWhitespace
            )
        )) ?? AttributedString(explanation)
    }

    /// The hover tooltip and VoiceOver hint carry the same
    /// text with the Markdown markers stripped.
    private var plain: String {
        String(rich.characters)
    }
}
