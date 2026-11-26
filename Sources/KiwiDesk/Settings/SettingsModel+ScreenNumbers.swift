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

    /// The number `display` holds in the draft, nil when it holds
    /// none.
    func screenNumber(of display: Display) -> Int? {
        screenOrder.numbers(of: display.fingerprint).first
    }

    /// Whether a pin to `key`'s screen or area lands: false for a
    /// connected screen left unnumbered, which a Save drops a pin to.
    func takesPins(_ key: String) -> Bool {
        let fingerprint = ScreenAreaKey(parsing: key).fingerprint
        guard displays.contains(where: { $0.fingerprint == fingerprint })
        else { return true }
        return !screenOrder.numbers(of: fingerprint).isEmpty
    }

    /// Draft pins to a number no connected screen holds: they wait.
    var waitingPins: [SpaceID: Int] {
        config.spacePins.filter { !screenOrder.holds($0.value) }
            .mapValues(\.number)
    }

    /// The connected screen left unnumbered at `number`'s place, nil
    /// where no connected screen holds the number at all (#3688).
    func unnumberedScreen(at number: Int) -> Display? {
        guard screenOrder.unnumbered.contains(number),
            screenOrder.fingerprints.indices.contains(number - 1)
        else { return nil }
        let fingerprint = screenOrder.fingerprints[number - 1]
        return displays.first { $0.fingerprint == fingerprint }
    }

    /// The waiting numbers whose screen is connected but left
    /// unnumbered, with that screen's label.
    var unnumberedWaits: [Int: String] {
        var result: [Int: String] = [:]
        for number in Set(waitingPins.values) {
            if let screen = unnumberedScreen(at: number) {
                result[number] = screenLabel(screen)
            }
        }
        return result
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

    /// Whether `display` may be left unnumbered: on the live target
    /// alone, a hole being the session's, and never for a twin.
    func canLeaveUnnumbered(_ display: Display) -> Bool {
        target == .live
            && screenOrder.unnumbering(display.fingerprint) != nil
    }

    /// Leaves `display` unnumbered for the session.
    func leaveUnnumbered(_ display: Display) {
        guard canLeaveUnnumbered(display),
            let next = screenOrder.unnumbering(display.fingerprint)
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
