import Carbon.HIToolbox
import KiwiDeskCore

/// The physical board the Shortcuts preview draws: which key
/// sits where, and how wide it is.
///
/// This has to be authored, because nothing in the app knows it.
/// `KeyCombo.keyCodes` is the only description of a keyboard the
/// app carries and it is a name→code dictionary — unordered,
/// alias-collapsed, and silent about rows and widths. Binding by
/// physical position (the 2026-07-15 ruling) is exactly why a
/// POSITION table is the missing half: the app already knows
/// which code a binding claims, and never where that code is.
///
/// The ANSI/ISO difference is DATA — a second row table, not a
/// branch inside the drawing. The two boards disagree about more
/// than one key (ISO adds `section` beside the left shift, cuts
/// that shift to 1.25u, and turns return into a tall key), so a
/// conditional would spread through every row; as a table it is
/// one lookup and a new physical type is a new entry.
enum KeyboardMatrix {

    /// A drawn key. `code` is nil for a filler no binding can
    /// claim (the tall-return notch), which still occupies its
    /// width so the rows below line up.
    struct Key: Equatable {
        let code: UInt32?
        /// Width in key units, 1.0 being a letter key.
        let units: Double
        /// What a code-less cap prints. A modifier carries no
        /// key code — a combo holds it in `HotkeyModifiers`, not
        /// as a key — so nothing could name ⇧ or ⌘ from the code
        /// alone, and they shipped blank. They are still
        /// unclaimable; they are just no longer anonymous.
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

    /// What macOS says is physically attached. Read, never
    /// stored — the layout row states it as "from macOS" for
    /// exactly that reason.
    enum PhysicalType: Equatable {
        case ansi
        case iso
        case jis

        /// `LMGetKbdType()` answers with a Carbon keyboard type;
        /// the ANSI/ISO/JIS split is what `KBGetLayoutType` maps
        /// it to, and it is the only part of that answer this
        /// preview needs.
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

    /// The rows, top to bottom. Modifier and navigation keys are
    /// included: they are drawn, and a modifier cap lights when
    /// the selected layers use it, so leaving them out would
    /// make the chip row point at nothing.
    static func rows(for type: PhysicalType) -> [[Key]] {
        switch type {
        case .iso: return isoRows
        case .ansi, .jis: return ansiRows
        }
    }

    // MARK: - Boards

    private static let ansiRows: [[Key]] = [
        [Key(50)] + digitRow,
        [Key(48, 1.5)] + qwertyRow + [Key(42, 1.5)],
        [Key(nil, 1.75, legend: "⇪")] + homeRow
            + [Key(36, 2.25)],
        [Key(nil, 2.25, legend: "⇧")] + bottomLetters
            + [Key(nil, 2.75, legend: "⇧")],
        spaceRow,
    ]

    /// ISO adds a key beside the left shift, shrinks that shift
    /// to make room, and makes return tall — modelled as a 1.5u
    /// return on the QWERTY row with a filler notch at the home
    /// row's end.
    ///
    /// **The two odd keycodes SWAP position on ISO**, which is
    /// the part worth knowing before "fixing" this table. On
    /// ANSI, 50 (`kVK_ANSI_Grave`) is the key left of `1` and 10
    /// (`kVK_ISO_Section`) does not exist. On ISO the same two
    /// codes sit the other way round: **10 is left of `1`** (the
    /// German `^`, the Nordic `§`) and **50 is beside the left
    /// shift** (the German `<`). Positions are what swap, not
    /// labels — so a board that reuses the ANSI order draws both
    /// keys with the right glyph in the wrong place, which is
    /// exactly how this shipped to its first sitting
    /// (owner, 2026-08-10, on a German ISO board).
    private static let isoRows: [[Key]] = [
        [Key(10)] + digitRow,
        [Key(48, 1.5)] + qwertyRow + [Key(36, 1.5)],
        [Key(nil, 1.75, legend: "⇪")] + homeRow
            + [Key(42), Key(nil, 1.25)],
        [Key(nil, 1.25, legend: "⇧"), Key(50)] + bottomLetters
            + [Key(nil, 2.75, legend: "⇧")],
        spaceRow,
    ]

    // MARK: - Shared runs

    /// Digits and their two trailing punctuation keys. The
    /// leading key is NOT here: it is 50 on ANSI and 10 on ISO
    /// (see `isoRows`), so each board prepends its own.
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

    /// The modifier row. `nil` caps are the ones no `KeyCombo`
    /// can name on its own — a combo carries its modifiers in
    /// `HotkeyModifiers`, so ⌃⌥⌘ have no key code to bind.
    private static let spaceRow: [Key] = [
        Key(nil, 1.25, legend: "⌃"),
        Key(nil, 1.25, legend: "⌥"),
        Key(nil, 1.25, legend: "⌘"),
        Key(49, 4.75),
        Key(nil, 1.25, legend: "⌘"),
        Key(nil, 1.25, legend: "⌥"),
        Key(123), Key(126), Key(125), Key(124),
    ]

    /// Every code the board draws, de-duplicated. The panel's
    /// "free" tally counts these, so a key the board does not
    /// draw is not counted as free — which is why this derives
    /// from the rows rather than from `KeyCombo.keyCodes`, whose
    /// aliases would count `escape` twice and whose entries
    /// include codes no row shows.
    static func drawnCodes(for type: PhysicalType) -> Set<UInt32> {
        Set(rows(for: type).flatMap { $0 }.compactMap(\.code))
    }
}
