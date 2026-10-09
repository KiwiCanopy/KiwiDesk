import AppKit
import CoreGraphics
import Foundation

@testable import KiwiDeskCore

private typealias F = BootRestoreFixture

/// The desk the cross-session restore suites share (#1385): a
/// core booted after a logout's freeze wrote `previous`, with the
/// reopened windows scanned into the shown Space.
@MainActor
protocol CrossSessionFixture {}

@MainActor
extension CrossSessionFixture {
    /// When the snapshot was written; the boot is one second on.
    static var before: Date { Date(timeIntervalSince1970: 9000) }
    static var frame: CGRect {
        CGRect(
            x: 80,
            y: 90,
            width: 600,
            height: 400
        )
    }
    /// Where a snapshot record put its window; never `frame`.
    static var recorded: CGRect {
        CGRect(
            x: 300,
            y: 220,
            width: 500,
            height: 350
        )
    }

    func window(
        _ id: UInt32,
        _ app: String,
        _ title: String
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: pid_t(100 + id),
            appName: app,
            appBundleID: app,
            title: title,
            frame: Self.frame
        )
    }

    /// The previous boot's desk, as a logout's freeze wrote it
    /// unless `frozen` is false: `rows` per Space, old ids from
    /// `first`.
    func previous(
        _ rows: [(space: SpaceID, app: String, title: String)],
        at: Date = Self.before,
        first: UInt32 = 500,
        frozen: Bool = true
    ) -> StateSnapshot {
        var records: [StateSnapshot.WindowRecord] = []
        var spaces: [SpaceID: [WindowID]] = [:]
        for (index, row) in rows.enumerated() {
            let id = WindowID(first + UInt32(index))
            records.append(
                .init(
                    id: id,
                    frame: Self.recorded,
                    app: row.app,
                    title: row.title
                )
            )
            spaces[row.space, default: []].append(id)
        }
        var snapshot = StateSnapshot(
            windows: records,
            spaces: [F.shown, F.hidden].map {
                .init(space: Space(id: $0, windows: spaces[$0] ?? []))
            },
            activeSpace: F.shown.raw,
            capturedAt: at
        )
        snapshot.frozenForLogout = frozen
        return snapshot
    }

    /// A core whose boot came after `before`, with `scanned`
    /// tracked in the shown Space.
    func boot(_ scanned: [ManagedWindow]) -> KiwiCore? {
        guard let core = F.makeCore() else { return nil }
        core.crash.bootTime = { Self.before.addingTimeInterval(1) }
        core.defersEventRetiles = true
        for window in scanned {
            core.handle(.windowCreated(window))
        }
        core.defersEventRetiles = false
        return core
    }

    /// Writes `snapshot` as the file the boot finds.
    func leave(_ snapshot: StateSnapshot, in core: KiwiCore) {
        core.crash.captureState = { snapshot }
        core.crash.autosave()
    }

    func arrange(_ core: KiwiCore) {
        core.arrangeBootDesk(session: core.crash.takeBootSnapshot())
    }

    func space(_ core: KiwiCore, _ id: UInt32) -> SpaceID? {
        core.state.workspaces.space(of: WindowID(id))
    }
}
