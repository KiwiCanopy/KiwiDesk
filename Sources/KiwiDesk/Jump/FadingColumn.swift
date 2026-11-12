import SwiftUI

/// A KiwiHub list that scrolls down: a `FadingScroll` that scrolls
/// the selected item clear of the fade by revealing the item past
/// it in the direction of travel, which fills the fade instead
/// (#3164; the ui-designer's call, delegated by the owner
/// 2026-11-11). The Windows list, the Desktops side's screen rows
/// and each Desktop's Space lines take it.
struct FadingColumn<Selected: Hashable, Content: View>: View {
    /// The selected item's id, where it is in this list.
    let selected: Selected?
    /// Every item's id, in order.
    let ids: [Selected]
    /// The margin above the first item and below the last.
    var inset: CGFloat = 0
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.panelSettled) private var settled
    /// Whether a key moved the selection since the list opened.
    @State private var moved = false

    var body: some View {
        ScrollViewReader { proxy in
            FadingScroll(inset: inset) { content }
                .onAppear { reveal(proxy, from: nil, animated: false) }
                .onChange(of: selected) { old, _ in
                    moved = true
                    reveal(proxy, from: old, animated: true)
                }
                .onChange(of: settled) { _, settled in
                    if settled { settle(proxy) }
                }
        }
    }

    private func reveal(
        _ proxy: ScrollViewProxy,
        from old: Selected?,
        animated: Bool
    ) {
        guard let target = Self.target(from: old, to: selected, in: ids)
        else { return }
        withAnimation(
            animated && !reduceMotion ? .easeOut(duration: 0.15) : nil
        ) {
            proxy.scrollTo(target)
        }
    }

    /// Puts the list back where it opened, once the panel's
    /// entrance has left it a few points off (#3203); a key that
    /// moved the selection meanwhile keeps the place it scrolled to.
    /// Bottom-anchored, the opening target lands where the opening
    /// reveal put it, a list whose target fits clamping at its top.
    private func settle(_ proxy: ScrollViewProxy) {
        guard !moved,
            let target = Self.target(from: nil, to: selected, in: ids)
                ?? ids.first
        else { return }
        proxy.scrollTo(target, anchor: .bottom)
    }

    /// What a reveal scrolls to: the item past `new` in the
    /// direction it moved from `old` (down when it did not move), or
    /// `new` itself at an end.
    nonisolated static func target(
        from old: Selected?,
        to new: Selected?,
        in ids: [Selected]
    ) -> Selected? {
        guard let new, let index = ids.firstIndex(of: new) else {
            return new
        }
        let before = old.flatMap { ids.firstIndex(of: $0) }
        let step = before.map { $0 > index ? -1 : 1 } ?? 1
        let next = index + step
        return ids.indices.contains(next) ? ids[next] : new
    }
}
