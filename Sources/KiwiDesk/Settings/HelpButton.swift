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
    /// The transient popover already dismisses on this very
    /// click's mouse-down; without the stamp the mouse-up
    /// action would immediately reopen it, making the button
    /// unable to ever close its own popover.
    @State private var dismissed = Date.distantPast

    /// Popover text measure — comfortable for 2–4 short lines
    /// without ballooning over the pane.
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
        // The same hover chip every icon-only borderless
        // button here carries — a bare glyph has nothing to
        // catch the eye drifting past the bordered control.
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
        .accessibilityLabel(L("help.button", "Help"))
        // A short action hint, not the content — VoiceOver
        // reads the explanation inside the popover after
        // activating, and `.help` above already exposes the
        // full text; duplicating it here would announce it
        // twice on every focus pass.
        .accessibilityHint(
            L(
                "help.button.hint",
                "Shows an explanation of this setting."
            )
        )
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

    /// The hover tooltip carries the same text with the
    /// Markdown markers stripped. The extra replace only bites
    /// when the Markdown parse failed and `rich` kept the raw
    /// markers; a successful parse has none left.
    private var plain: String {
        String(rich.characters)
            .replacingOccurrences(of: "**", with: "")
    }
}
