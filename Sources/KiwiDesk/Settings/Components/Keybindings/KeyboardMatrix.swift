import Carbon.HIToolbox
import KiwiDeskCore

/// Physical keyboard matrix definitions for shortcut layout preview
/// (ruling 2026-07-15).
enum KeyboardMatrix {

    /// Visual representation of a key on the matrix board (`HotkeyModifiers`).
    struct Key: Equatable {
        let code: UInt32?
        let units: Double
        let legend: String?

        init(
            _ code: UInt32?,
            _ units: Double = 1,
            legend: String? = nil
        ) {
            self.code = code
            self.units = units
            self.legend = legend
        }
    }

    /// Physical layout type reported by macOS.
    enum PhysicalType: Equatable {
        case ansi
        case iso
        case jis

        /// Resolves active keyboard layout type via `LMGetKbdType()` and
        /// `KBGetLayoutType`.
        static func current(
            _ kbdType: Int = Int(LMGetKbdType())
        ) -> PhysicalType {
            let layout = KBGetLayoutType(Int16(kbdType))
            if layout == PhysicalKeyboardLayoutType(kKeyboardISO) {
                return .iso
            }
            if layout == PhysicalKeyboardLayoutType(kKeyboardJIS) {
                return .jis
            }
            return .ansi
        }
    }

    /// Returns matrix key rows for layout type.
    static func rows(for type: PhysicalType) -> [[Key]] {
        switch type {
        case .iso: return isoRows
        case .ansi, .jis: return ansiRows
        }
    }

    private static let ansiRows: [[Key]] = [
        [Key(50)] + digitRow,
        [Key(48, 1.5)] + qwertyRow + [Key(42, 1.5)],
        [Key(nil, 1.75, legend: "⇪")] + homeRow
            + [Key(36, 2.25)],
        [Key(nil, 2.25, legend: "⇧")] + bottomLetters
            + [Key(nil, 2.75, legend: "⇧")],
        spaceRow,
    ]

    /// ISO rows. The two odd keycodes SWAP position vs ANSI:
    /// 10 (`kVK_ISO_Section`) sits left of `1` and 50
    /// (`kVK_ANSI_Grave`) beside the left shift — positions swap,
    /// not labels, so reusing the ANSI order draws both glyphs in
    /// the wrong place, which is how this first shipped (owner
    /// 2026-08-10, German ISO board).
    private static let isoRows: [[Key]] = [
        [Key(10)] + digitRow,
        [Key(48, 1.5)] + qwertyRow + [Key(36, 1.5)],
        [Key(nil, 1.75, legend: "⇪")] + homeRow
            + [Key(42), Key(nil, 1.25)],
        [Key(nil, 1.25, legend: "⇧"), Key(50)] + bottomLetters
            + [Key(nil, 2.75, legend: "⇧")],
        spaceRow,
    ]

    /// Digits and trailing punctuation. The LEADING key is not
    /// here: it is 50 on ANSI and 10 on ISO (see `isoRows`), so
    /// each board prepends its own.
    private static let digitRow: [Key] = [
        Key(18), Key(19), Key(20), Key(21), Key(23),
        Key(22), Key(26), Key(28), Key(25), Key(29), Key(27),
        Key(24), Key(51, 2),
    ]

    private static let qwertyRow: [Key] = [
        Key(12), Key(13), Key(14), Key(15), Key(17), Key(16),
        Key(32), Key(34), Key(31), Key(35), Key(33), Key(30),
    ]

    private static let homeRow: [Key] = [
        Key(0), Key(1), Key(2), Key(3), Key(5), Key(4), Key(38),
        Key(40), Key(37), Key(41), Key(39),
    ]

    private static let bottomLetters: [Key] = [
        Key(6), Key(7), Key(8), Key(9), Key(11), Key(45),
        Key(46), Key(43), Key(47), Key(44),
    ]

    /// Modifier row. `nil` caps are the keys no `KeyCombo` can
    /// name — a combo carries modifiers in `HotkeyModifiers`, so
    /// ⌃⌥⌘⇧ have no key code to bind.
    private static let spaceRow: [Key] = [
        Key(nil, 1.25, legend: "⌃"),
        Key(nil, 1.25, legend: "⌥"),
        Key(nil, 1.25, legend: "⌘"),
        Key(49, 4.75),
        Key(nil, 1.25, legend: "⌘"),
        Key(nil, 1.25, legend: "⌥"),
        Key(123), Key(126), Key(125), Key(124),
    ]

    /// Unique keycodes the board draws — derived from the rows,
    /// never from `KeyCombo.keyCodes`, whose aliases would count
    /// `escape` twice and whose entries include codes no row
    /// shows; the panel's "free" tally counts these.
    static func drawnCodes(for type: PhysicalType) -> Set<UInt32> {
        Set(rows(for: type).flatMap { $0 }.compactMap(\.code))
    }
}
