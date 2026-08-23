import SwiftUI

/// The ONE composition point for a row's action menu (#845).
///
/// A row hands its menu builder to `rowActions(id:_:)` ONCE, and
/// the seam applies it to all three channels — right-click
/// (`.contextMenu`), VoiceOver (`.accessibilityActions`), and a
/// keyboard chord on the row that contains focus. A site never
/// spells a channel beside the seam: per-site application is how
/// a crossed pairing (menu A's builder on menu B's channel) or a
/// stale mirrored list ships, and `KeyboardActionParityTests`
/// reds on a bare channel outside this file. A FOURTH channel
/// joins here, once, and every row has it.
///
/// The chord is `⌃.` (Control-Period — deliberately not `⌘.`,
/// macOS's Cancel equivalent), bound by the one
/// `.keyboardShortcut` below, which the parity suite needles so
/// prose stating the chord cannot drift from the code.
///
/// FOCUS-GATED, and that is the load-bearing part (#845 review):
/// `.keyboardShortcut` registers window-wide and SwiftUI
/// resolves duplicates by hierarchy order, not focus — so N
/// identical per-row bindings sent `⌃.` to the FIRST row
/// whatever held focus, cross-targeting destructive items. Each
/// row instead publishes its identity through
/// `FocusedValues.rowActionFocus` while the row OR ANY
/// DESCENDANT holds focus, and only the row whose identity
/// matches installs the hidden zero-size `Menu` that binds the
/// chord — one live binding at a time, anchored at its own row,
/// inert while no row has focus. The hidden menu draws nothing
/// and consumes no mouse-down, so `.draggable` rows keep their
/// drag. A row joining the family must be able to HOLD focus at
/// all (`SpaceAssignmentChip` takes `.focusable()` for exactly
/// this), and whether the chord LANDS is a device fact — verify
/// with keyboard navigation ON; no headless guard can hear it.
private struct RowActionFocusKey: FocusedValueKey {
    typealias Value = AnyHashable
}

extension FocusedValues {
    /// The identity of the row whose subtree currently holds
    /// keyboard focus — published by `rowActions(id:_:)`, read
    /// back by each row to decide whether ITS chord binding is
    /// the live one.
    var rowActionFocus: AnyHashable? {
        get { self[RowActionFocusKey.self] }
        set { self[RowActionFocusKey.self] = newValue }
    }
}

extension View {
    /// Offers `menu` as the row's action menu on every channel:
    /// right-click, VoiceOver actions, and `⌃.` while this
    /// row's subtree holds focus. `id` must be unique among the
    /// rows on screen — it is what routes the chord to the
    /// focused row and no other.
    func rowActions<ID: Hashable, MenuContent: View>(
        id: ID,
        @ViewBuilder _ menu: @escaping () -> MenuContent
    ) -> some View {
        modifier(
            RowActions(id: AnyHashable(id), menu: menu)
        )
    }
}

private struct RowActions<MenuContent: View>: ViewModifier {
    let id: AnyHashable
    let menu: () -> MenuContent
    @FocusedValue(\.rowActionFocus) private var focusedRow

    func body(content: Content) -> some View {
        content
            .contextMenu { menu() }
            .accessibilityActions { menu() }
            .focusedValue(\.rowActionFocus, id)
            .background(alignment: .topLeading) {
                if focusedRow == id {
                    Menu {
                        menu()
                    } label: {
                        EmptyView()
                    }
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .keyboardShortcut(".", modifiers: .control)
                    .accessibilityHidden(true)
                }
            }
    }
}
