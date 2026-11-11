import Foundation

/// The arrival-focus verdict the fold reads (#3152): a quiet open's
/// window takes no focus (#3122, #3141), and a new window takes it
/// only where its app holds the keys, read through the one #1322
/// gate, whose sibling-process step asks LaunchServices: the one
/// arrival read that may, sibling apps only. KiwiDesk's own windows
/// always take it, since the GUI fronts them (#1281, #1414).
extension KiwiCore {
    func arrivalFocus(of window: ManagedWindow) -> ArrivalFocus {
        let now = wallClock()
        if let app = window.appRef.listKey,
            launchFollow.opensQuietly(app, at: now)
        {
            return .quiet(into: launchFollow.quietSpace(app, at: now))
        }
        return EventLoop.isOwnProcess(window.pid)
            || eventLoop.reportsFromActiveApp(window.pid)
            ? .foreground : .background
    }
}
