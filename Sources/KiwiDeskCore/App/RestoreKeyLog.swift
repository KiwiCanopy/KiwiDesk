import Foundation

/// A #1385 step 2 MEASUREMENT, to be removed once step 3 is
/// ruled: logs the stable key a cross-boot restore would match on
/// — bundle id, title, rank within (app, Space) — for every
/// tracked window, at each autosave and once at boot adoption.
///
/// Reads state only, never AX. Rank is the window's position
/// among its app's windows in the Space's flat array order;
/// `appRank` the same over the whole desk, Spaces in workspace
/// order. An autosave batch is logged only when it differs from
/// the last one logged.
///
/// OFF unless opted in, since window titles reach the unified log
/// unredacted. The flag is read once, at the first use (boot):
///
///     defaults write com.kiwicanopy.kiwidesk RestoreKeyLog -bool YES
///     defaults delete com.kiwicanopy.kiwidesk RestoreKeyLog
///
/// Removal: this file, `CrashRecovery.restoreKeys` and
/// `onAutosaved`, their wiring and the call in `arrangeBootDesk`.
@MainActor
final class RestoreKeyLog {
    enum Phase: String {
        case autosave
        case boot
    }

    /// The prefix a `log show` predicate filters on.
    static let prefix = "restore-key:"
    /// The opt-in user default.
    static let defaultsKey = "RestoreKeyLog"

    /// The opt-in read; a test injects its answer.
    var isOptedIn: () -> Bool = {
        UserDefaults.standard.bool(forKey: RestoreKeyLog.defaultsKey)
    }
    private lazy var enabled = isOptedIn()
    private var lastAutosave: [String]?

    /// Logs the autosave batch unless it repeats the last one.
    func autosave(_ core: KiwiCore) {
        guard enabled else { return }
        let lines = Self.lines(.autosave, of: core.state)
        guard lines != lastAutosave else { return }
        lastAutosave = lines
        Self.emit(lines, phase: .autosave, to: core.onLog)
    }

    /// Logs every window the boot scan adopted.
    func boot(_ core: KiwiCore) {
        guard enabled else { return }
        Self.emit(
            Self.lines(.boot, of: core.state),
            phase: .boot,
            to: core.onLog
        )
    }

    private static func emit(
        _ lines: [String],
        phase: Phase,
        to log: @MainActor (String) -> Void
    ) {
        log("\(prefix) phase=\(phase.rawValue) count=\(lines.count)")
        lines.forEach(log)
    }

    /// One line per (Space, window) membership, then the windows
    /// filed in no Space under `space=-`, in WindowID order.
    static func lines(
        _ phase: Phase,
        of state: StateCoordinator
    ) -> [String] {
        var groups: [(String, [WindowID])] =
            state.workspaces.allSpaces.map { ($0.id.raw, $0.windows) }
        let filed = Set(groups.flatMap(\.1))
        let unfiled = state.windows.all.map(\.id)
            .filter { !filed.contains($0) }
            .sorted { $0.raw < $1.raw }
        if !unfiled.isEmpty { groups.append(("-", unfiled)) }
        var appRanks: [String: Int] = [:]
        var lines: [String] = []
        for (space, ids) in groups {
            var ranks: [String: Int] = [:]
            for id in ids {
                guard let window = state.windows[id] else { continue }
                let app = window.appBundleID ?? "?\(window.appName)"
                let rank = ranks[app, default: 0]
                let appRank = appRanks[app, default: 0]
                ranks[app] = rank + 1
                appRanks[app] = appRank + 1
                lines.append(
                    "\(prefix) phase=\(phase.rawValue) space=\(space)"
                        + " rank=\(rank) appRank=\(appRank)"
                        + " window=w\(id.raw) app=\(app)"
                        + " title=\(String(reflecting: window.title))"
                )
            }
        }
        return lines
    }
}
