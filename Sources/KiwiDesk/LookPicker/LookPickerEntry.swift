import KiwiDeskCore

/// One card of the look picker (#3038): a look of the library, or
/// the worn look no library look matches, drawn first as "Current"
/// (owner ruling Q5).
struct LookPickerEntry: Identifiable, Equatable {
    enum Kind: Equatable {
        /// The worn look, not saved.
        case current
        case bundled
        case saved
    }

    var look: ShelfLook
    var kind: Kind

    var id: String {
        switch kind {
        case .current: "current"
        case .bundled: "bundled:\(look.name)"
        case .saved: "saved:\(look.name)"
        }
    }

    /// The cards in picker order: Current first where it exists,
    /// then the bundled looks, then the saved ones.
    static func cards(
        current: ShelfLook?,
        bundled: [ShelfLook],
        saved: [ShelfLook]
    ) -> [LookPickerEntry] {
        let head = current.map { [LookPickerEntry(look: $0, kind: .current)] }
        return (head ?? [])
            + bundled.map { LookPickerEntry(look: $0, kind: .bundled) }
            + saved.map { LookPickerEntry(look: $0, kind: .saved) }
    }

    /// `settings` with this card's look on: what ↩ gives. The
    /// Current card is the settings themselves.
    func painted(over settings: TilingSettings) -> TilingSettings {
        kind == .current ? settings : look.painted(over: settings)
    }
}
