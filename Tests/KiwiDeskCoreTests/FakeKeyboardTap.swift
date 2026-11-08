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

    init(
        _ consumers: Set<KeyboardTapConsumer>,
        _ fire: @escaping KeyboardTap.Fire = { _ in }
    ) {
        self.consumers = consumers
        self.fire = fire
    }

    func setSideRows(_ rows: [SideTapRow]) { self.rows = rows }
    func setTapRows(_ rows: [ModifierTapRow]) { tapRows = rows }
    func stop() { stopped = true }
}
