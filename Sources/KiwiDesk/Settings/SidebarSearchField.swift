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

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            field
            if !text.isEmpty { clearButton }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(fieldShape)
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    private var field: some View {
        TextField(
            L("sidebar.search.placeholder", "Search"),
            text: $text
        )
        .textFieldStyle(.plain)
        .font(.callout)
        // Escape clears, matching `NSSearchField`.
        .onExitCommand { text = "" }
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
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            L("sidebar.search.clear", "Clear search")
        )
    }

    private var fieldShape: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.quaternary)
    }
}
