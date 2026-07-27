import KiwiDeskCore
import SwiftUI

/// The System Settings-style search field at the top of the
/// sidebar (#90). Hand-built chrome, not `.searchable`: the
/// window's toolbar is deliberately empty (see
/// `SettingsView.chrome`) and the identity header already
/// hand-tunes the top safe area, so SwiftUI's toolbar-managed
/// placement would reopen exactly that brittle interaction.
/// Matches the `AppPickerButton` / `IconPicker` field
/// precedent instead.
struct SidebarSearchField: View {
    @Binding var text: String
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
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            field
            if !text.isEmpty { clearButton }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(fieldShape)
        .inactiveDimmed()
        .padding(.horizontal, 10)
        // Shift the field down within the same 8 pt vertical
        // allowance so it sits midway between identity and header.
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    private var field: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(
                L("sidebar.search.placeholder", "Search")
            )
            .foregroundStyle(Color.secondary.opacity(0.42))
        )
        .textFieldStyle(.plain)
        .font(.body)
        .focused($focused)
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
            L("sidebar.search.placeholder", "Search")
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
            L("sidebar.search.clear", "Clear search")
        )
    }

    /// A full pill: `Capsule` derives its radius from the field's
    /// height. Keyboard focus gets the restrained accent outline
    /// of System Settings, not SwiftUI's oversized default halo.
    private var fieldShape: some View {
        Capsule()
            .fill(Color.primary.opacity(0.06))
            .overlay {
                Capsule()
                    .strokeBorder(
                        Color.accentColor.opacity(
                            focused ? 0.38 : 0
                        ),
                        lineWidth: 3
                    )
            }
            .shadow(
                color: Color.accentColor.opacity(
                    focused ? 0.12 : 0
                ),
                radius: 2
            )
            .animation(
                .easeOut(duration: 0.12),
                value: focused
            )
    }
}
