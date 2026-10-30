import AppKit

/// The revealer's live machine touch (#761): the pointer monitors
/// both `makeTestCore` twins pin inert, and the live delayed call.
extension ShelfRevealer {
    /// The pointer events the revealer hears: moves, and a left
    /// drag's moves, so a window drag can open the Space Bar
    /// (#2795). A held button sends no `.mouseMoved`.
    static let heard: NSEvent.EventTypeMask = [
        .mouseMoved, .leftMouseDragged,
    ]

    /// Both arms, as `PointerRest`'s: moves go to the ACTIVE app,
    /// so while KiwiDesk is active only the local monitor hears.
    /// Each delivery says whether the left button drags.
    static func live(
        _ deliver: @escaping @MainActor (CGPoint?, Bool) -> Void
    ) -> Any? {
        let global = NSEvent.addGlobalMonitorForEvents(
            matching: heard
        ) {
            let point = $0.locationInWindow
            let dragging = $0.type == .leftMouseDragged
            Task { @MainActor in deliver(point, dragging) }
        }
        let local = NSEvent.addLocalMonitorForEvents(
            matching: heard
        ) { event in
            let dragging = event.type == .leftMouseDragged
            Task { @MainActor in deliver(nil, dragging) }
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
