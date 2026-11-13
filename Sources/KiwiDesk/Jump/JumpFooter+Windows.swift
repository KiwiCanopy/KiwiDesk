import AppKit
import KiwiDeskCore
import SwiftUI

/// The Windows footer's own hints, in their order; the lit index
/// and the collapse both count by it (#3249).
enum WindowsHint: Int, CaseIterable {
    case jump, moveHere, swapHere, digits
}

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
    /// The hints that collapse, in order (#3249 ▸ Ruling 3); ↩ Jump
    /// never does.
    static let collapseOrder: [WindowsHint] = [
        .swapHere, .digits, .moveHere,
    ]

    /// Every chord of the three modifiers. A collapse level is chosen
    /// only where all of them fit, so a press never changes which
    /// hints are keycaps.
    static let heldStates: [NSEvent.ModifierFlags] = [
        [], .shift, .option, .command, [.shift, .option],
        [.shift, .command], [.option, .command],
        [.shift, .option, .command],
    ]

    /// The hint `held` picks, read off `JumpKey` as the lit hint is:
    /// the digits where they answer the chord, else ↩'s pick.
    func windowsPick(_ held: NSEvent.ModifierFlags) -> WindowsHint? {
        // ⌃ is left out: the chord that opened the panel may still
        // be held when it draws.
        let held = held.intersection([.shift, .option, .command])
        switch JumpKey.of(
            keyCode: UInt16(JumpKey.digitRows[0]),
            modifiers: held,
            scope: .windows,
            naming: naming
        ) {
        // A held chord the digits answer lights them first, though
        // ↩ under it picks as well (#2931 ▸ Ruling 5).
        case .quick, .quickSwap: return .digits
        default: break
        }
        switch JumpKey.of(
            keyCode: JumpKey.returnKey,
            modifiers: held,
            scope: .windows,
            naming: naming
        ) {
        case .pick(let moveHere): return moveHere ? .moveHere : .jump
        case .swapHere: return .swapHere
        default: return nil
        }
    }

    /// The lit Windows hint: the pick, unless the selection would
    /// refuse it (#2885).
    var windowsLeading: Int? {
        switch windowsPick(modifiers) {
        case .moveHere:
            return selectionMoves ? WindowsHint.moveHere.rawValue : nil
        case .swapHere:
            return selectionSwaps ? WindowsHint.swapHere.rawValue : nil
        case let pick: return pick?.rawValue
        }
    }

    /// Jump, Move here, Swap here, the digits, then the navigation
    /// hints, worded for `held`.
    func windowsSlots(held: NSEvent.ModifierFlags) -> [JumpFooterSlot] {
        let worded = windowsPick(held)
        let own: [(WindowsHint, String, String?)] = [
            (.jump, L("jump.footer.jump", "%1$@ Jump", "↩"), nil),
            (
                .moveHere,
                L("jump.footer.move_here", "%1$@ Move here", "⇧↩"),
                "⇧"
            ),
            (
                .swapHere,
                L("jump.footer.swap_here", "%1$@ Swap here", "⌥↩"),
                "⌥"
            ),
            (.digits, Self.digitsHint(held), "⌘"),
        ]
        return own.map { hint, text, keycap in
            JumpFooterSlot(
                text: text,
                keycap: keycap,
                held: keycap != nil && hint == worded
            )
        }
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
    /// The candidates are one list of `WindowsFit` steps, so their
    /// ids never collide: `ViewThatFits` traps on a repeated child id
    /// (#3271).
    var windowsFitted: some View {
        let levels = Self.collapseOrder.count
        let count = windowsSlots(held: modifiers).count
        return ViewThatFits(in: .horizontal) {
            ForEach(
                WindowsFit.steps(levels: levels, count: count),
                id: \.self
            ) { step in
                switch step {
                case .collapsed(let level):
                    windowsStable(level)
                case .shed(let shown):
                    windowsRow(
                        held: modifiers,
                        level: levels,
                        shown: shown,
                        lit: leading
                    )
                }
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
        let drawn = windowsDrawn(held: held, level: level, shown: shown)
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

extension JumpFooter {
    /// What each slot of a Windows line draws: its words, or its
    /// keycap where `level` collapses it and `held` does not word it.
    func windowsDrawn(
        held: NSEvent.ModifierFlags,
        level: Int,
        shown: Int? = nil
    ) -> [String] {
        let all = windowsSlots(held: held)
        let collapsed = Set(Self.collapseOrder.prefix(level).map(\.rawValue))
        let slots = Array(all.prefix(shown ?? all.count))
        return slots.indices.map { index in
            let slot = slots[index]
            return collapsed.contains(index) && !slot.held
                ? slot.keycap ?? slot.text : slot.text
        }
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

/// One `windowsFitted` candidate: the line at a keycap collapse
/// level, or past all of them shedding to `shown` hints.
enum WindowsFit: Hashable {
    case collapsed(Int)
    case shed(Int)

    /// Every collapse level, then the line shedding from the end.
    static func steps(levels: Int, count: Int) -> [WindowsFit] {
        (0...levels).map(collapsed) + (0...count).reversed().map(shed)
    }
}
