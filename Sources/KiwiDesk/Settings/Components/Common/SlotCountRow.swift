import KiwiDeskCore
import SwiftUI

/// "Windows on screen" — the count a scrolling share IS, beneath
/// the Percent slider (#1382); the noun is the user's, a column
/// being tiler vocabulary, and the anchor's caption owns what a
/// centred row cuts at the edges. Typeable like
/// every stepper (an integer only), writing the count's share
/// into the one stored fraction; "—" (spoken "not a whole
/// count") when the share is not `1/n`. Every count↔share step
/// is `ScrollSize`'s, and ▲ greys at `cap`, Core's count of what
/// the screen fits (`SlotCountRowTests`).
struct SlotCountRow: View {
    @Binding var size: ScrollSize
    let isVertical: Bool
    /// ▲'s bound (`KiwiCore.scrollingColumnCap`).
    let cap: Int
    @State private var text = ""
    /// What the store last seeded into the field; a blur commits
    /// only text that differs from it, so tabbing through writes
    /// nothing and a seed never re-arms an edit.
    @State private var seeded = ""
    @FocusState private var focused: Bool

    private var label: String {
        L("slot_count.label", "Windows on screen")
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
        let next = count.map { $0 + 1 } ?? ScrollSize.countAbove(f)
        return next <= cap ? next : nil
    }

    /// Where ▼ lands: the previous count, or the first whole
    /// count below an off-count share.
    var down: Int? {
        guard let f = fraction else { return nil }
        let next = count.map { $0 - 1 } ?? ScrollSize.countBelow(f)
        return next >= 1 ? next : nil
    }

    var body: some View {
        SettingsRowShape {
            SettingsRowLabel(
                label: label,
                help: L(
                    "slot_count.help",
                    "Sizes windows so exactly this many fit, gaps "
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
            if !focused { seed() }
        }
        .onAppear(perform: seed)
    }

    private var field: some View {
        TextField(
            L("slot_count.none_glyph", "—"),
            text: $text
        )
        .labelsHidden()
        .accessibilityLabel(label)
        // The field's value is its text (#812); only the empty
        // state needs words.
        .accessibilityValue(
            text.isEmpty ? L("slot_count.none", "not a whole count") : text
        )
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
        if text != seeded, let n = Self.typed(text, cap: cap) {
            write(n)
        }
        seed()
    }

    /// What a typed entry lands on: an integer clamped to 1…`cap`,
    /// nothing else — a fraction is the slider's, not this field's.
    static func typed(_ text: String, cap: Int) -> Int? {
        Int(text).map { min(max($0, 1), cap) }
    }

    private func seed() {
        seeded = count.map(String.init) ?? ""
        text = seeded
    }

    /// Writes the count's share into the one stored fraction.
    func write(_ n: Int) {
        size = .fraction(clamping: ScrollSize.share(of: n))
    }
}
