import KiwiDeskCore

/// What numbers the draft's target gives the connected screens
/// (#3647 ▸ lane 2): the stored target's own sets, read at
/// `reload`, and the draft's renumber, committed at Save.
struct ScreenNumbering: Equatable {
    /// A stored target's screen setups; nil for the live target.
    var stored: [MonitorSet]?
    /// The draft's order for the connected screens; nil until a
    /// badge pick changes it.
    var draft: ScreenOrder?
}

/// The Screens cards' number badge and menu (#3647 ▸ lane 2): every
/// pick goes through these, and the draft's pins follow the number
/// they hold, since `screenOrder` reads the draft first.
extension SettingsModel {
    /// The target's order before the draft's renumber.
    var baseScreenOrder: ScreenOrder {
        screenNumbering.stored.map(core.screenOrder(holding:))
            ?? core.liveScreenOrder
    }

    /// Whether the draft renumbered the connected screens.
    var screenNumbersEdited: Bool { screenNumbering.draft != nil }

    /// The number `display` holds in the draft, nil for a screen
    /// outside its order.
    func screenNumber(of display: Display) -> Int? {
        screenOrder.numbers(of: display.fingerprint).first
    }

    /// Draft pins to a number no connected screen holds: they wait.
    var waitingPins: [SpaceID: Int] {
        config.spacePins.filter { !screenOrder.holds($0.value) }
            .mapValues(\.number)
    }

    /// How many numbers the connected setup has.
    var screenNumberCount: Int { screenOrder.fingerprints.count }

    /// Gives `display` Screen `number`; the screen holding it swaps.
    func useScreenNumber(_ number: Int, for display: Display) {
        guard
            let next = screenOrder.renumbering(
                display.fingerprint,
                to: number
            )
        else { return }
        setDraftScreenOrder(next)
    }

    /// Takes the draft's renumber back: the Screen numbers row's ↺.
    func revertScreenNumbers() {
        setDraftScreenOrder(nil)
    }

    private func setDraftScreenOrder(_ order: ScreenOrder?) {
        screenNumbering.draft = order == baseScreenOrder ? nil : order
        recomputeDirty()
    }
}
