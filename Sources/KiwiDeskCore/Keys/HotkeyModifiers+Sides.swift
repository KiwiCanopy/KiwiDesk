import CoreGraphics
import Foundation

/// One of the four modifiers that has a left and a right key
/// (#2601).
public enum ModifierKind: CaseIterable, Sendable {
    case control, option, shift, command

    /// The either-side bit Carbon reads.
    public var plain: HotkeyModifiers {
        switch self {
        case .control: return .control
        case .option: return .option
        case .shift: return .shift
        case .command: return .command
        }
    }
}

/// Which key of a modifier pair a sided shortcut names (#2601).
public enum ModifierSide: CaseIterable, Sendable {
    case left, right
}

extension HotkeyModifiers {
    /// The side bit for `kind` on `side` — bits Carbon never sets,
    /// above `hyper`. A sided modifier also carries its plain bit,
    /// so stripping `sides` leaves the either-side chord.
    public static func side(
        _ side: ModifierSide,
        of kind: ModifierKind
    ) -> HotkeyModifiers {
        let index: UInt32
        switch kind {
        case .control: index = 0
        case .option: index = 1
        case .shift: index = 2
        case .command: index = 3
        }
        let offset: UInt32 = side == .left ? 0 : 4
        return HotkeyModifiers(rawValue: 1 << (21 + index + offset))
    }

    /// Every side bit.
    public static let sides: HotkeyModifiers = ModifierKind.allCases
        .reduce(into: []) { mask, kind in
            for side in ModifierSide.allCases {
                mask.insert(.side(side, of: kind))
            }
        }

    /// The chord with its sides forgotten: what Carbon registers
    /// and what a side-blind reading compares.
    public var unsided: HotkeyModifiers { subtracting(.sides) }

    /// Whether any modifier names a side.
    public var isSided: Bool { !isDisjoint(with: .sides) }

    /// The side `kind` names here, nil for either side or absent.
    public func side(of kind: ModifierKind) -> ModifierSide? {
        ModifierSide.allCases.first { contains(.side($0, of: kind)) }
    }

    /// The modifiers a key event holds, sides included, read from
    /// its device flags (⌃ 0x01/0x2000, ⇧ 0x02/0x04, ⌘ 0x08/0x10,
    /// ⌥ 0x20/0x40; measured on macOS 27, #2601).
    public static func held(by flags: CGEventFlags) -> HotkeyModifiers {
        let raw = flags.rawValue
        var held: HotkeyModifiers = []
        let device: [(ModifierKind, UInt64, UInt64)] = [
            (.control, 0x01, 0x2000),
            (.shift, 0x02, 0x04),
            (.command, 0x08, 0x10),
            (.option, 0x20, 0x40),
        ]
        let plain: [(ModifierKind, CGEventFlags)] = [
            (.control, .maskControl), (.shift, .maskShift),
            (.command, .maskCommand), (.option, .maskAlternate),
        ]
        for (kind, mask) in plain where flags.contains(mask) {
            held.insert(kind.plain)
        }
        for (kind, left, right) in device {
            if raw & left != 0 { held.insert(.side(.left, of: kind)) }
            if raw & right != 0 { held.insert(.side(.right, of: kind)) }
        }
        return held
    }

    /// Whether a press holding `held` (from `held(by:)`) answers a
    /// chord with these modifiers: the same modifiers, and each
    /// named side down. Either side answers an unsided modifier.
    public func answers(_ held: HotkeyModifiers) -> Bool {
        guard held.unsided == unsided else { return false }
        return ModifierKind.allCases.allSatisfy { kind in
            guard let side = side(of: kind) else { return true }
            return held.contains(.side(side, of: kind))
        }
    }
}
