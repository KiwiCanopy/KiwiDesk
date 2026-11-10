import Foundation

/// The arrival-focus verdict the fold reads (#3152): a quiet open's
/// window takes no focus (#3122, #3141), and a new window takes it
/// only where its app holds the keys, read through the one #1322
/// gate. KiwiDesk's own windows always take it, since the GUI fronts
/// them (#1281, #1414).
extension KiwiCore {
    func arrivalFocus(of window: ManagedWindow) -> ArrivalFocus {
        let app = window.appRef.listKey
        if launchFollow.opensQuietly(app, at: wallClock()) {
            return .quiet(into: launchFollow.holds.spaces[app])
        }
        let own = window.pid == ProcessInfo.processInfo.processIdentifier
        return own || eventLoop.reportsFromActiveApp(window.pid)
            ? .foreground : .background
    }
}
