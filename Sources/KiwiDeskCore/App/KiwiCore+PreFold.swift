import CoreGraphics
import Foundation

/// The reads `KiwiCore.handle` must take BEFORE `state.apply`
/// folds an event in — split from `KiwiCore+Events.swift`
/// (350-line ceiling). Each is a snapshot of state the fold is
/// about to overwrite or remove, threaded into the arm that
/// consumes it.
extension KiwiCore {
    /// The frame before a move/resize folds in — the drag
    /// coordinator anchors a gesture's start on it (#933).
    func preEventFrame(of event: KiwiEvent) -> CGRect? {
        switch event {
        case .windowMoved(let id, _),
            .windowResized(let id, _):
            return state.windows[id]?.frame
        default:
            return nil
        }
    }

    /// The gone window's owner before a destroy/hide folds in:
    /// the gone-path forget parks the size-bound ledger under
    /// it (#1049), and after `state.apply` the window is no
    /// longer readable.
    func goneWindowPID(of event: KiwiEvent) -> pid_t? {
        switch event {
        case .windowDestroyed(let id, _),
            .windowHidden(let id):
            return state.windows[id]?.pid
        default:
            return nil
        }
    }
}
