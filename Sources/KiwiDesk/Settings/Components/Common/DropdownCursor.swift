import AppKit
import SwiftUI

/// The one cursor of a searchable dropdown KiwiDesk draws itself —
/// the font and app pickers and the header search: the pointer and
/// the keys move the same highlight, as a native menu's do, but the
/// pointer only by real motion, so a row sliding under a still
/// pointer — a scroll, a re-filter, the opening — takes nothing
/// (#2229's rule). Leaving the list keeps it, so Return always has
/// a target. KiwiHub keeps its own model (#2365).
struct DropdownCursor<ID: Hashable> {
    /// The row Return acts on.
    private(set) var highlighted: ID?
    /// Where the pointer stood when a row or a key last heard it.
    private(set) var lastPointer: CGPoint?

    /// The list opens: the cursor starts at `start`, never under
    /// the pointer, whose resting place is recorded.
    mutating func opened(at start: ID?, pointer: CGPoint) {
        highlighted = start
        lastPointer = pointer
    }

    /// The pointer over `id`; it takes the cursor only where the
    /// pointer moved since the last row or key heard it.
    mutating func hover(_ id: ID, pointer: CGPoint) {
        guard pointer != lastPointer else { return }
        lastPointer = pointer
        highlighted = id
    }

    /// ↑/↓ by `step` over `ids`, from the cursor — from the first or
    /// last row where it sits on none. The row it lands on, nil
    /// for an empty list.
    @discardableResult
    mutating func keyMove(
        _ step: Int,
        in ids: [ID],
        pointer: CGPoint
    ) -> ID? {
        lastPointer = pointer
        guard !ids.isEmpty else { return nil }
        let index = highlighted.flatMap { ids.firstIndex(of: $0) }
        let next = index.map { $0 + step } ?? (step > 0 ? 0 : ids.count - 1)
        let id = ids[min(max(next, 0), ids.count - 1)]
        highlighted = id
        return id
    }

    /// A query edit: the keyboard puts the cursor on `id`.
    mutating func reset(to id: ID?, pointer: CGPoint) {
        highlighted = id
        lastPointer = pointer
    }

    /// Return: the row it picks, nil where the cursor sits on none
    /// of `ids`.
    mutating func commit(in ids: [ID], pointer: CGPoint) -> ID? {
        lastPointer = pointer
        guard let highlighted, ids.contains(highlighted) else {
            return nil
        }
        return highlighted
    }
}

/// The pointer now, in screen points — the dropdowns' one live
/// read, so a still pointer reads alike from every row.
@MainActor
enum DropdownPointer {
    static func live() -> CGPoint { NSEvent.mouseLocation }
}

/// How the cursor row draws (owner ruling 2026-10-17): solid
/// `accent` behind it and the inks KiwiHub's selected row measures
/// on it; every other row draws nothing.
enum DropdownRowStyle {
    static func fill(_ onCursor: Bool) -> Color {
        onCursor ? SettingsTheme.accent : .clear
    }

    static func ink(_ onCursor: Bool) -> AnyShapeStyle {
        onCursor
            ? AnyShapeStyle(SettingsTheme.accentInk)
            : AnyShapeStyle(.primary)
    }

    static func secondaryInk(_ onCursor: Bool) -> Color {
        onCursor ? SettingsTheme.accentInkSecondary : SettingsTheme.ink3
    }
}

extension View {
    /// A dropdown row: the cursor's fill behind it, and `onPoint`
    /// on every pointer event over it, which hands the row to
    /// `DropdownCursor.hover` with the live pointer.
    func dropdownCursorRow(
        _ onCursor: Bool,
        cornerRadius: CGFloat = 5,
        onPoint: @escaping () -> Void
    ) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(DropdownRowStyle.fill(onCursor))
        )
        .onContinuousHover { phase in
            if case .active = phase { onPoint() }
        }
    }
}
