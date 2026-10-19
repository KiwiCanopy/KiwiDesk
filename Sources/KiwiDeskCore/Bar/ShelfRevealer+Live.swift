import AppKit

/// The revealer's live machine touch (#761): the pointer monitors
/// both `makeTestCore` twins pin inert, and the live delayed call.
extension ShelfRevealer {
    /// Both arms, as `PointerRest`'s: moves go to the ACTIVE app,
    /// so while KiwiDesk is active only the local monitor hears.
    static func live(
        _ deliver: @escaping @MainActor (CGPoint?) -> Void
    ) -> Any? {
        let global = NSEvent.addGlobalMonitorForEvents(
            matching: .mouseMoved
        ) {
            let point = $0.locationInWindow
            Task { @MainActor in deliver(point) }
        }
        let local = NSEvent.addLocalMonitorForEvents(
            matching: .mouseMoved
        ) { event in
            Task { @MainActor in deliver(nil) }
            return event
        }
        return [global, local].compactMap { $0 }
    }
}

/// A cancellable delayed call (`ShelfRevealer.schedule`).
@MainActor
final class ShelfRevealTimer {
    private var task: Task<Void, Never>?
    private let onCancel: () -> Void

    init(task: Task<Void, Never>? = nil, onCancel: @escaping () -> Void = {}) {
        self.task = task
        self.onCancel = onCancel
    }

    func cancel() {
        task?.cancel()
        task = nil
        onCancel()
    }

    /// The live schedule: a main-actor task sleeping `delay`.
    static func after(
        _ delay: TimeInterval,
        _ body: @escaping @MainActor () -> Void
    ) -> ShelfRevealTimer {
        ShelfRevealTimer(
            task: Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                body()
            }
        )
    }
}
