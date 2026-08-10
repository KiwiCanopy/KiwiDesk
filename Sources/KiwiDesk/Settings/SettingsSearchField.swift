import KiwiDeskCore
import SwiftUI

/// The System Settings-style search field (#90), since #678
/// turn 9 mounted inside the header's search popover rather
/// than a sidebar. Hand-built chrome, not `.searchable`: the
/// window's toolbar is deliberately empty (see
/// `SettingsView.chrome`), so SwiftUI's toolbar-managed
/// placement would reopen exactly that brittle interaction.
/// Matches the `AppPickerButton` / `IconPicker` field
/// precedent instead.
struct SettingsSearchField: View {
    @Binding var text: String
    /// Focus, owned by the caller. The field mounts in the header
    /// and lives as long as the window does, so it must NOT grab
    /// focus on appear — but ⌘K has to be able to put focus here
    /// from anywhere, and that shortcut belongs to the header. A
    /// `FocusState` binding is how the two share one focus.
    let focus: FocusState<Bool>.Binding
    /// Moves the highlighted result while focus stays in the
    /// field, System Settings-style. Without this the results
    /// were mouse-only: the `List` never takes focus while the
    /// user is typing, so ↑/↓ went nowhere.
    ///
    /// No default value, deliberately: a default on a required
    /// collaboration is fail-open — a second call site that forgot
    /// it would get a silently mouse-only field, which is the bug
    /// this parameter exists to fix.
    let onMove: (MoveCommandDirection) -> Void
    /// Return reveals the highlighted result. Separate from
    /// `onMove` on purpose — arrowing navigates (cheap), Return
    /// commits to the scroll and flash.
    let onCommit: () -> Void
    /// The ⌘K hint, shown only while the field is empty and
    /// unfocused — once someone is typing it is noise, and it
    /// would sit where the clear button belongs.
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
            // `ink3`, not `.secondary.opacity(0.42)` (~1.64:1):
            // the field carries no visible label, so the prompt
            // is the only thing naming the control and cannot be
            // a whisper.
            prompt: Text(
                L("search.placeholder", "Search")
            )
            .foregroundStyle(SettingsTheme.ink3)
        )
        .textFieldStyle(.plain)
        .font(.body)
        .focused(focus)
        // Escape clears, matching `NSSearchField`.
        .onExitCommand { text = "" }
        // `onKeyPress`, not `onMoveCommand`: the latter has no
        // pass-through, so it would swallow ←/→ and break caret
        // movement inside the field. Returning `.ignored` for
        // anything else is the whole point — including for a
        // MODIFIED arrow. The `KeyEquivalent` overload matches
        // whatever the modifiers are, so claiming ↑/↓ there also
        // ate ⇧↑ (extend selection to start) and ⌘↑ (caret to
        // start), two standard text-editing shortcuts.
        .onKeyPress { press in
            // Subtracting, not `isEmpty`: AppKit reports an arrow
            // key with `.function` and `.numericPad` set, so an
            // `isEmpty` test can refuse EVERY bare arrow and
            // silently kill the navigation this exists to restore
            // — a green build says nothing about it either way.
            // Only the three intent-carrying modifiers may claim
            // the key back for text editing.
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
        // Explicit name, so accessibility does not depend on
        // the placeholder staying non-decorative.
        .accessibilityLabel(
            L("search.placeholder", "Search")
        )
    }

    /// Clearing is a control, not a choice (the icon picker's
    /// rule): an explicit affordance instead of
    /// select-all-delete, shown only while there is something
    /// to clear.
    private var clearButton: some View {
        Button {
            text = ""
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .iconButtonAffordance(
            L("search.clear", "Clear search")
        )
    }

    /// The chip shape the header row's other tokens use, not the
    /// `Capsule` this shipped as: the field sits between the back
    /// chip and the profile chip, and a pill among rounded rects
    /// reads as a different KIND of thing. Keyboard focus gets the
    /// restrained accent outline of System Settings, not SwiftUI's
    /// oversized default halo.
    private var fieldShape: some View {
        ChipMetrics.shape
            .fill(SettingsTheme.sunken)
            // Full-strength accent, not 0.55: `.textFieldStyle`
            // `.plain` removes the system focus ring, so this
            // stroke IS the focus indicator and there is nothing
            // underneath it. Blended at 0.55 over `sunken` it
            // measured 1.52:1 against the field — a focus state
            // that replaces the platform's must be at least as
            // legible as the one it replaced.
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
                .easeOut(duration: 0.12),
                value: focus.wrappedValue
            )
    }
}
