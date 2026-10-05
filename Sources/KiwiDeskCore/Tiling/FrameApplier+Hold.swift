import ApplicationServices
import CoreGraphics
import Foundation

/// Frame writes held per window until a deadline (#1956): the plate
/// slide's incoming windows land under their plates only once the
/// strip does. A held write is staged here and sent from the app's
/// own queue AT the deadline, so a main-thread stall delays no
/// landing; a later write for a staged window replaces its frame
/// (latest wins, a size set is never dropped). Its entries live
/// one landing: a release, `releaseAll` or `dropAll` ends them, and
/// an expired deadline is pruned at the next hold. A native-tab
/// re-key inside a hold lands the staged frame on the old element
/// — accepted, the window being one landing behind at worst.
final class HeldWrites: @unchecked Sendable {
    struct Entry: Equatable {
        var frame: CGRect
        var setSize: Bool
    }

    enum Staging: Equatable {
        /// Folded into a write already staged.
        case merged
        /// Staged; a release is owed at the deadline.
        case staged(DispatchTime)
        /// Not held: write now.
        case pass
    }

    enum Release: Equatable {
        case write(Entry)
        /// The window was held again past this release.
        case later(DispatchTime)
        case none
    }

    private let lock = NSLock()
    private var deadlines: [WindowID: DispatchTime] = [:]
    private var staged: [WindowID: Entry] = [:]

    /// Holds every write to `ids` until `deadline`; a window held
    /// already takes the later of the two.
    func hold(_ ids: some Sequence<WindowID>, until deadline: DispatchTime) {
        lock.lock()
        defer { lock.unlock() }
        let now = DispatchTime.now()
        deadlines = deadlines.filter {
            now < $0.value || staged[$0.key] != nil
        }
        for id in ids {
            deadlines[id] = max(deadlines[id] ?? deadline, deadline)
        }
    }

    /// Whether a write to `id` is staged.
    func isStaged(_ id: WindowID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return staged[id] != nil
    }

    /// Whether `id` is held at `now`.
    func isHeld(_ id: WindowID, now: DispatchTime = .now()) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return deadlines[id].map { now < $0 } ?? false
    }

    func stage(
        _ id: WindowID,
        _ frame: CGRect,
        setSize: Bool,
        now: DispatchTime = .now()
    ) -> Staging {
        lock.lock()
        defer { lock.unlock() }
        if var entry = staged[id] {
            entry.frame = frame
            entry.setSize = entry.setSize || setSize
            staged[id] = entry
            return .merged
        }
        guard let deadline = deadlines[id], now < deadline else {
            deadlines[id] = nil
            return .pass
        }
        staged[id] = Entry(frame: frame, setSize: setSize)
        return .staged(deadline)
    }

    /// Ends every hold now; returns the windows with a staged
    /// write, which the caller sends at once.
    func releaseAll() -> [WindowID] {
        lock.lock()
        defer { lock.unlock() }
        deadlines = [:]
        return Array(staged.keys)
    }

    /// Forgets every hold and staged write — KiwiDesk is stopping,
    /// and a landing after the quit gather would undo it.
    func dropAll() {
        lock.lock()
        defer { lock.unlock() }
        deadlines = [:]
        staged = [:]
    }

    /// Drops `id`'s staged write, which no element can take; the
    /// hold stands.
    func drop(_ id: WindowID) {
        lock.lock()
        defer { lock.unlock() }
        staged[id] = nil
    }

    /// The staged write a release at `now` sends, or the later
    /// deadline it must wait for instead.
    func release(_ id: WindowID, now: DispatchTime = .now()) -> Release {
        lock.lock()
        defer { lock.unlock() }
        if let deadline = deadlines[id], now < deadline {
            return staged[id] == nil ? .none : .later(deadline)
        }
        deadlines[id] = nil
        return staged.removeValue(forKey: id).map(Release.write) ?? .none
    }
}

extension FrameApplier {
    /// Holds every write to `ids` until `deadline` (#1956).
    func holdWrites(
        _ ids: some Sequence<WindowID>,
        until deadline: DispatchTime
    ) {
        held.hold(ids, until: deadline)
    }

    /// Ends every hold — the plate slide's play was dropped — and
    /// sends what they kept. The holds are the slide's alone.
    func releaseAllHolds() {
        for id in held.releaseAll() { releaseHeld(id, at: .now()) }
    }

    /// Stages `frame` for a held window; true when it was held, so
    /// the caller sends nothing now.
    func stageHeld(_ id: WindowID, _ frame: CGRect, setSize: Bool) -> Bool {
        switch held.stage(id, frame, setSize: setSize) {
        case .pass: return false
        case .merged: return true
        case .staged(let deadline):
            releaseHeld(id, at: deadline)
            return true
        }
    }

    /// Sends `id`'s staged write at `deadline` from its app's own
    /// queue — KiwiDesk's own window through AppKit on main.
    private func releaseHeld(_ id: WindowID, at deadline: DispatchTime) {
        guard let element = elementProvider(id),
            let pid = Self.pid(of: element)
        else {
            held.drop(id)
            return
        }
        let own = pid == getpid()
        nonisolated(unsafe) let target = element
        let held = held
        let writer = writer
        let holds = enhancedUI
        let recent = recentStamp
        let move = ownWindowMove
        let reschedule: @Sendable (DispatchTime) -> Void = {
            [weak self] later in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.releaseHeld(id, at: later)
                }
            }
        }
        // Noted at the release, not here: a hold noted now would
        // keep the app's running instant batch open until it fires.
        // The generation tells a release the loop let go of the app
        // meanwhile, which then toggles nothing.
        let atRest = own ? false : enhancedUIAtRest(pid)
        let generation = holds.generation(pid)
        queue(for: pid).asyncAfter(deadline: deadline) {
            switch held.release(id) {
            case .write(let entry):
                if own {
                    MainActor.assumeIsolated {
                        if !move(id, entry.frame, entry.setSize) {
                            Self.write(entry, target, writer)
                        }
                    }
                } else if holds.noteQueued(
                    pid,
                    atRest: atRest,
                    ifGeneration: generation
                ) {
                    holds.beginInstant(pid, writer)
                    Self.write(entry, target, writer)
                    holds.endInstant(pid, writer)
                } else {
                    Self.write(entry, target, writer)
                }
                recent(id)  // as `apply`, #1254
            case .later(let later):
                reschedule(later)
            case .none:
                break
            }
        }
    }

    nonisolated private static func write(
        _ entry: HeldWrites.Entry,
        _ target: AXUIElement,
        _ writer: FrameWriter
    ) {
        if entry.setSize {
            writer.setFrame(entry.frame, target)
        } else {
            writer.setPosition(entry.frame.origin, target)
        }
    }
}
