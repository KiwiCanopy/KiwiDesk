import Foundation

/// A physical key the user may turn into KiwiDesk's Hyper key
/// (#1870). KiwiDesk remaps it to F18 through `hidutil`
/// (`HyperKeyRemap`) and watches F18 with a Carbon hotkey, so no
/// Input Monitoring is needed. Keys that type text are not
/// cases: picking one would cost that character everywhere.
///
/// The raw value is the wire spelling (`set_hyper_key`) and a
/// stored value (`gui.json`'s `hyper.key`): renaming one owes a
/// `ConfigMigration` step (§5).
public enum HyperSourceKey: String, CaseIterable, Sendable {
    case capsLock = "caps_lock"
    case leftCommand = "left_command"
    case rightCommand = "right_command"
    case leftOption = "left_option"
    case rightOption = "right_option"
    case leftControl = "left_control"
    case rightControl = "right_control"
    case leftShift = "left_shift"
    case rightShift = "right_shift"
    case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12
    case f13, f14, f15, f16, f17, f18, f19, f20

    /// What the key gives up while it is Hyper, for the caption
    /// the GUI renders (#96: Core names, the GUI narrates).
    public enum Kind: Sendable, Equatable {
        case capsLock
        /// A modifier, and whether it is the right-hand one.
        case modifier(right: Bool)
        /// A key macOS gives a job of its own (F1–F12).
        case systemKey
        /// A key with no job of its own (F13–F20).
        case spare
    }

    public var kind: Kind {
        switch self {
        case .capsLock: .capsLock
        case .leftCommand, .leftOption, .leftControl, .leftShift:
            .modifier(right: false)
        case .rightCommand, .rightOption, .rightControl,
            .rightShift:
            .modifier(right: true)
        case .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10,
            .f11, .f12:
            .systemKey
        case .f13, .f14, .f15, .f16, .f17, .f18, .f19, .f20:
            .spare
        }
    }

    /// The key code macOS reports for it in an `NSEvent` — a
    /// modifier's carries its side.
    public var keyCode: UInt16 {
        Self.codes[self]!.virtual
    }

    /// The key's HID usage on the keyboard page (0x07).
    var hidUsage: UInt64 { UInt64(Self.codes[self]!.usage) }

    /// The source a key code names, or nil for a key that cannot
    /// be Hyper.
    public init?(keyCode: UInt16) {
        let match = Self.codes.first { $0.value.virtual == keyCode }
        guard let match else { return nil }
        self = match.key
    }

    /// The key the remapped key arrives as: the remap's
    /// destination, the Carbon trigger's key, and what the GUI
    /// recorder reads as held Hyper (#2414).
    public static let trigger = HyperSourceKey.f18

    /// The trigger's key code, which the Carbon trigger listens on.
    static let triggerKeyCode = UInt32(trigger.keyCode)

    /// The trigger's HID usage, the remap's destination.
    static let triggerUsage = trigger.hidUsage

    private static let codes:
        [HyperSourceKey: (virtual: UInt16, usage: UInt8)] = [
            .capsLock: (57, 0x39),
            .leftControl: (59, 0xE0), .leftShift: (56, 0xE1),
            .leftOption: (58, 0xE2), .leftCommand: (55, 0xE3),
            .rightControl: (62, 0xE4), .rightShift: (60, 0xE5),
            .rightOption: (61, 0xE6), .rightCommand: (54, 0xE7),
            .f1: (122, 0x3A), .f2: (120, 0x3B), .f3: (99, 0x3C),
            .f4: (118, 0x3D), .f5: (96, 0x3E), .f6: (97, 0x3F),
            .f7: (98, 0x40), .f8: (100, 0x41), .f9: (101, 0x42),
            .f10: (109, 0x43), .f11: (103, 0x44), .f12: (111, 0x45),
            .f13: (105, 0x68), .f14: (107, 0x69), .f15: (113, 0x6A),
            .f16: (106, 0x6B), .f17: (64, 0x6C), .f18: (79, 0x6D),
            .f19: (80, 0x6E), .f20: (90, 0x6F),
        ]
}

extension HyperSourceKey {
    /// The sided modifier key this is, nil for any other key
    /// (#2601): the one mapping the recorder and the spoken form
    /// read.
    public var modifierSide: (kind: ModifierKind, side: ModifierSide)? {
        switch self {
        case .leftCommand: (.command, .left)
        case .rightCommand: (.command, .right)
        case .leftOption: (.option, .left)
        case .rightOption: (.option, .right)
        case .leftControl: (.control, .left)
        case .rightControl: (.control, .right)
        case .leftShift: (.shift, .left)
        case .rightShift: (.shift, .right)
        default: nil
        }
    }

    /// The key that is `side` of `kind`.
    public static func key(
        _ side: ModifierSide,
        of kind: ModifierKind
    ) -> HyperSourceKey {
        switch (kind, side) {
        case (.command, .left): .leftCommand
        case (.command, .right): .rightCommand
        case (.option, .left): .leftOption
        case (.option, .right): .rightOption
        case (.control, .left): .leftControl
        case (.control, .right): .rightControl
        case (.shift, .left): .leftShift
        case (.shift, .right): .rightShift
        }
    }
}
