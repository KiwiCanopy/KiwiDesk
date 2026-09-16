import KiwiDeskCore
import SwiftUI

/// "Columns on screen" / "Rows on screen" — the count a scrolling
/// share IS, beneath the Percent slider (#1382). Typeable like
/// every stepper (an integer only), writing `1/n` into the one
/// stored fraction; "—" (spoken "not a whole count") when the
/// share is not `1/n` at the wire's precision. ▲ from "—" lands
/// on `ceil(1/f)`, ▼ on `floor(1/f)` — never "nearest", which
/// reverses direction at the shipped 95% — and ▲ greys at `cap`,
/// Core's count of what the widest screen fits
/// (`SlotCountRowTests`).
struct SlotCountRow: View {
    @Binding var size: ScrollSize
    let isVertical: Bool
    /// ▲'s bound (`TilingSettings.scrollingColumnCap`).
    let cap: Int
    @State private var text = ""
    @FocusState private var focused: Bool

    private var label: String {
        isVertical
            ? L("slot_count.rows", "Rows on screen")
            : L("slot_count.columns", "Columns on screen")
    }

    /// The stored share, `auto` resolving to its orientation's.
    private var fraction: Double? {
        switch size {
        case .fraction(let f): return f
        case .auto:
            return isVertical
                ? ScrollSize.autoVerticalFraction
                : ScrollSize.autoHorizontalFraction
        case .points: return nil
        }
    }

    /// The whole count, or nil for "—".
    var count: Int? { fraction.flatMap(ScrollSize.count(of:)) }

    /// Where ▲ lands: the next count, or the first whole count
    /// above an off-count share.
    var up: Int? {
        guard let f = fraction else { return nil }
        let next = count.map { $0 + 1 } ?? Int((1 / f).rounded(.up))
        return next <= cap ? next : nil
    }

    /// Where ▼ lands: the previous count, or the first whole
    /// count below an off-count share.
    var down: Int? {
        guard let f = fraction else { return nil }
        let next = count.map { $0 - 1 } ?? Int((1 / f).rounded(.down))
        return next >= 1 ? next : nil
    }

    var body: some View {
        SettingsRowShape {
            SettingsRowLabel(
                label: label,
                help: L(
                    "slot_count.help",
                    "Sets the size so this many fit exactly, gaps "
                        + "included; stops where one more would fall "
                        + "under the minimum window size."
                )
            )
        } control: {
            HStack {
                field
                Stepper(
                    onIncrement: up.map { n in { write(n) } },
                    onDecrement: down.map { n in { write(n) } }
                ) {}
                .labelsHidden()
                .controlSize(.large)
                .accessibilityLabel(label)
                .accessibilityValue(spokenValue)
            }
        }
        .onChange(of: size) { _, _ in
            if !focused { text = count.map(String.init) ?? "" }
        }
        .onAppear { text = count.map(String.init) ?? "" }
    }

    private var field: some View {
        TextField(
            L("slot_count.none_glyph", "—"),
            text: $text
        )
        .labelsHidden()
        .accessibilityLabel(label)
        .accessibilityValue(spokenValue)
        .frame(width: 48)
        .multilineTextAlignment(.trailing)
        .monospacedDigit()
        .textFieldStyle(.roundedBorder)
        .focused($focused)
        .onSubmit(commit)
        .onChange(of: focused) { _, now in
            if !now { commit() }
        }
    }

    private var spokenValue: String {
        count.map(String.init)
            ?? L("slot_count.none", "not a whole count")
    }

    private func commit() {
        if let typed = Int(text) {
            write(min(max(typed, 1), cap))
        }
        text = count.map(String.init) ?? ""
    }

    /// Writes `1/n` into the one stored fraction.
    private func write(_ n: Int) {
        size = .fraction(clamping: 1 / Double(n))
    }
}
