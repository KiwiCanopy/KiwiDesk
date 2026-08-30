import KiwiDeskCore
import SwiftUI

/// Search input field with keyboard navigation and shortcut hint (#90, #678,
/// `SettingsView.chrome`).
struct SettingsSearchField: View {
    @Binding var text: String
    /// Shared FocusState binding for programmatic focus (⌘K).
    let focus: FocusState<Bool>.Binding
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    /// Moves result highlight while maintaining field focus.
    let onMove: (MoveCommandDirection) -> Void
    /// Commits selection and performs search reveal.
    let onCommit: () -> Void
    /// Whether to display ⌘K shortcut hint when empty and unfocused.
    let shortcutHint: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SettingsTheme.ink3)
            field
            if !text.isEmpty {
                clearButton
            } else if shortcutHint, !focus.wrappedValue {
                Text("⌘K")
                    .font(.caption2)
                    .foregroundStyle(SettingsTheme.ink3)
            }
        }
        .padding(.horizontal, ChipMetrics.padH)
        .padding(.vertical, ChipMetrics.padV)
        .background(fieldShape)
        .inactiveDimmed()
    }

    private var field: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(
                L("search.placeholder", "Search")
            )
            .foregroundStyle(SettingsTheme.ink3)
        )
        .textFieldStyle(.plain)
        .font(.body)
        .focused(focus)
        .onExitCommand { text = "" }
        .onKeyPress { press in
            guard
                press.modifiers.intersection(
                    [.shift, .command, .option]
                ).isEmpty
            else { return .ignored }
            switch press.key {
            case .upArrow:
                onMove(.up)
                return .handled
            case .downArrow:
                onMove(.down)
                return .handled
            default:
                return .ignored
            }
        }
        .onSubmit(onCommit)
        .accessibilityLabel(
            L("search.placeholder", "Search")
        )
    }

    /// Clear text button affordance.
    private var clearButton: some View {
        Button {
            text = ""
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(SettingsTheme.ink2)
        }
        .buttonStyle(.plain)
        .iconButtonAffordance(
            L("search.clear", "Clear search")
        )
    }

    /// Header chip-shaped background and custom focus ring (#1069).
    private var fieldShape: some View {
        ChipMetrics.shape
            .fill(SettingsTheme.sunken)
            .overlay {
                ChipMetrics.shape
                    .strokeBorder(
                        focus.wrappedValue
                            ? SettingsTheme.accent
                            : Color.clear,
                        lineWidth: 3
                    )
            }
            .shadow(
                color: SettingsTheme.accent.opacity(
                    focus.wrappedValue ? 0.12 : 0
                ),
                radius: 2
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: focus.wrappedValue
            )
    }
}
