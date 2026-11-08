@testable import KiwiDeskCore

/// The keyboard tap a test reads instead of a session-wide one
/// (#565): it records the rows each consumer was handed, and
/// fires a row on the test's word through the manager's own
/// `fire` closure.
final class FakeKeyboardTap: KeyboardTapHandle {
    let consumers: Set<KeyboardTapConsumer>
    let fire: KeyboardTap.Fire
    var rows: [SideTapRow] = []
    var tapRows: [ModifierTapRow] = []
    var stopped = false
    /// How many times the manager handed it rows.
    var handed = 0

    init(
        _ consumers: Set<KeyboardTapConsumer>,
        _ fire: @escaping KeyboardTap.Fire = { _ in }
    ) {
        self.consumers = consumers
        self.fire = fire
    }

    func setRows(_ rows: KeyboardTapRows) {
        handed += 1
        self.rows = rows.sides
        tapRows = rows.taps
    }
    func stop() { stopped = true }
}
