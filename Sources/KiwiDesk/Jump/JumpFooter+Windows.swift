import AppKit
import KiwiDeskCore
import SwiftUI

/// One Windows footer hint: its words, and the keycap it collapses
/// to where the line runs short (#3249); nil for a hint that only
/// sheds.
struct JumpFooterSlot: Equatable {
    let text: String
    let keycap: String?
    /// Whether it is the hint the held modifiers pick, which keeps
    /// it worded.
    let held: Bool
}

extension JumpFooter {
    /// The slots that collapse, in order: Swap here, the digits,
    /// then Move here (#3249 ▸ Ruling 3). ↩ Jump never does.
    static let collapseOrder = [2, 3, 1]

    /// The held states a collapse level must fit in all of, so a
    /// press of one modifier never changes which hints are keycaps.
    /// A two-modifier chord re-words only the digits; where that
    /// overflows the line, it takes one keycap more while held.
    static let heldStates: [NSEvent.ModifierFlags] = [
        [], .shift, .option, .command,
    ]

    /// The one slot `held` keeps worded: the hint its pick lights,
    /// the digits under ⌘, Swap here under ⌥, Move here under ⇧.
    static func wordedSlot(_ held: NSEvent.ModifierFlags) -> Int? {
        if held.contains(.command) { return 3 }
        if held.contains(.option) { return 2 }
        if held.contains(.shift) { return 1 }
        return nil
    }

    /// Jump, Move here, Swap here, the digits, then the navigation
    /// hints, worded for `held`.
    func windowsSlots(held: NSEvent.ModifierFlags) -> [JumpFooterSlot] {
        let worded = Self.wordedSlot(held)
        return [
            JumpFooterSlot(
                text: L("jump.footer.jump", "%1$@ Jump", "↩"),
                keycap: nil,
                held: false
            ),
            JumpFooterSlot(
                text: L("jump.footer.move_here", "%1$@ Move here", "⇧↩"),
                keycap: "⇧",
                held: worded == 1
            ),
            JumpFooterSlot(
                text: L("jump.footer.swap_here", "%1$@ Swap here", "⌥↩"),
                keycap: "⌥",
                held: worded == 2
            ),
            JumpFooterSlot(
                text: Self.digitsHint(held),
                keycap: "⌘",
                held: worded == 3
            ),
        ]
            + windowsNavigation(sideHint).map {
                JumpFooterSlot(text: $0, keycap: nil, held: false)
            }
    }

    /// The Windows digits' hint: ⇧ and ⌥ already rewrite it to
    /// what the digits then do; ⌘ joining only lights it.
    static func digitsHint(_ held: NSEvent.ModifierFlags) -> String {
        if held.contains(.option) {
            return L(
                "jump.footer.quick_swap_here",
                "%1$@ Quick swap here",
                "⌥⌘1–9"
            )
        }
        if held.contains(.shift) {
            return L(
                "jump.footer.quick_move_here",
                "%1$@ Quick move here",
                "⇧⌘1–9"
            )
        }
        return L("jump.footer.quick", "%1$@ Quick jump", "⌘1–9")
    }

    /// The Windows side's navigation hints, which never light
    /// (#2246): ← → along the strip, the side switch, then the
    /// last-app opener last, so it sheds first (#3159).
    func windowsNavigation(_ other: String) -> [String] {
        var hints: [String] = []
        if stripSteps {
            hints.append(L("jump.footer.apps", "%1$@ Apps", "← →"))
        }
        hints.append(other)
        if let lastAppChord {
            hints.append(
                L("jump.footer.next_app", "%1$@ Next app", lastAppChord)
            )
        }
        return hints
    }

    /// The fewest keycaps at which every held state fits, then, past
    /// all of them, the line shedding from the end (#3249).
    var windowsFitted: some View {
        let levels = Self.collapseOrder.count
        let count = windowsSlots(held: modifiers).count
        return ViewThatFits(in: .horizontal) {
            ForEach(0...levels, id: \.self) { windowsStable($0) }
            ForEach((0...count).reversed(), id: \.self) {
                windowsRow(held: modifiers, level: levels, shown: $0)
            }
            row([], fixed: false)
        }
    }

    /// The line at `level` as wide as its widest held state, so the
    /// fit is decided once per locale and a press only re-words it.
    private func windowsStable(_ level: Int) -> some View {
        ZStack {
            ForEach(Self.heldStates, id: \.rawValue) {
                windowsRow(held: $0, level: level).hidden()
            }
            windowsRow(held: modifiers, level: level, lit: leading)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    /// One Windows line: `level` slots of `collapseOrder` drawn as
    /// keycaps, save the one `held` words, `shown` slots at most. A
    /// changed hint eases its width as a row's ⌘ digit does (#1875);
    /// the lit hint is the only one in full ink.
    func windowsRow(
        held: NSEvent.ModifierFlags,
        level: Int,
        shown: Int? = nil,
        lit: Int? = nil
    ) -> some View {
        let all = windowsSlots(held: held)
        let slots = Array(all.prefix(shown ?? all.count))
        let collapsed = Set(Self.collapseOrder.prefix(level))
        let drawn = slots.enumerated().map { index, slot in
            collapsed.contains(index) && !slot.held
                ? slot.keycap ?? slot.text : slot.text
        }
        return HStack(spacing: 8) {
            ForEach(Array(drawn.enumerated()), id: \.offset) { index, text in
                if index > 0 { Text(verbatim: "·") }
                if text == slots[index].keycap {
                    JumpKeycap(glyph: text).transition(.opacity)
                } else {
                    Text(text)
                        .foregroundStyle(
                            index == lit
                                ? AnyShapeStyle(.primary)
                                : AnyShapeStyle(.secondary)
                        )
                        .transition(.opacity)
                }
            }
            .accessibilityHidden(true)
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.15),
            value: drawn
        )
        .fixedSize(horizontal: true, vertical: false)
    }
}

/// A modifier hint collapsed to its key (#3249): the glyph in a
/// hairline key outline, in the footer's ink.
struct JumpKeycap: View {
    let glyph: String

    var body: some View {
        Text(verbatim: glyph)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(.tertiary, lineWidth: 1)
            )
    }
}
