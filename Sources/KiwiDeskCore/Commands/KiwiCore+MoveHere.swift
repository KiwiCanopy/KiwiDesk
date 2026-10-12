import Foundation

/// `move_here <bundle id> [text]` (#1513 ▸ Ruling): ONE window of
/// an app — its most recently focused open window not already in
/// the Space the user is on, a minimized one only once none is left
/// — moved here and focused through Jump to window's `moveHere(_:)`
/// (#1875). Each press takes the next, so repeats walk the app's
/// windows. `text` narrows to titles containing it. `gather` is the
/// all-windows verb (#1510).
extension KiwiCore {
    /// What `move_here` resolved to.
    enum MoveHerePick: Equatable {
        case window(WindowID)
        /// No matching window can move here — each is in native
        /// full screen; Move here cues why.
        case unmovable(WindowID)
        /// Every matching window is already in this Space.
        case allHere
        /// The app has windows, and none matches the text.
        case noMatch(text: String)
        /// The app has no window KiwiDesk knows.
        case noWindow
    }

    func moveHereCommand(_ args: [JSONValue]) -> CommandResponse {
        guard let bundleID = args.first?.stringValue?.lowercased()
        else { return .fail("expected app bundle id") }
        let text = args.dropFirst().first?.stringValue
            .flatMap { $0.isEmpty ? nil : $0 }
        guard let active = state.workspaces.activeSpace else {
            return .fail("no active Space to move into")
        }
        switch moveHerePick(bundleID: bundleID, into: active, text: text) {
        case .window(let id), .unmovable(let id):
            onLog("move_here: \(bundleID) — w\(id.raw)")
            return moveHere(.window(id))
                ? .ok() : .fail("could not move the \(bundleID) window here")
        case .allHere:
            cueMoveHere(.allHere(app: appName(bundleID)))
            return .fail("every \(bundleID) window is already here")
        case .noMatch(let text):
            cueMoveHere(.noTitleMatch(app: appName(bundleID), text: text))
            return .fail("no \(bundleID) window matches \(text)")
        case .noWindow:
            // A hidden app's windows are not in state (#913).
            if let pid = openOrFocus.runningAppPID(bundleID),
                eventLoop.appIsHidden(pid)
            {
                moveHiddenApp(pid, into: active, matching: text)
                return .ok()
            }
            if let text {
                cueMoveHere(
                    .noTitleMatch(app: appName(bundleID), text: text)
                )
                return .fail("no \(bundleID) window matches \(text)")
            }
            return launch([.string(bundleID)], newInstance: false)
        }
    }

    /// The pick, by `JumpTier`: open windows — tracked and, with the
    /// Desktop bridge, up on an away Desktop, in ring order — before
    /// minimized ones, each by recency. A window already drawn in
    /// `active` counts as here — a sticky window the gate holds is
    /// always drawn here, so the gate refuses no candidate; a
    /// full-screen window is picked only where nothing else can
    /// move, so Move here cues why.
    func moveHerePick(
        bundleID: String,
        into active: SpaceID,
        text: String?
    ) -> MoveHerePick {
        let away =
            canDriveDesktops
            ? Set(awayWindows(bundleID: bundleID).filter(\.isUp).map(\.id))
            : []
        let ring = cycleRing(bundleID: bundleID, away: away)
        let known = jump.knownWindows()
        let minimized = state.minimizeOrder.reversed()
            .filter { record in
                record.bundleID?.lowercased() == bundleID
                    && (known.map { $0.contains(record.id) } ?? true)
            }
        guard !ring.isEmpty || !minimized.isEmpty else {
            return .noWindow
        }
        let title: (WindowID) -> String = { [state] id in
            state.windows[id]?.title ?? state.awayWindows[id]?.title
                ?? minimized.first { $0.id == id }?.title ?? ""
        }
        let matching: (WindowID) -> Bool = { id in
            text.map { Self.titleMatches(title(id), $0) } ?? true
        }
        let open = ring.filter(matching)
        let elsewhere = open.filter { !isDrawnHere($0, active) }
        let movable = elsewhere.filter(movableHere)
        let parked = minimized.map(\.id).filter(matching)
        let pid =
            openOrFocus.runningAppPID(bundleID)
            ?? ring.first.flatMap { state.windows[$0]?.pid }
        if let id = mostRecentWindow(of: movable, pid: pid)
            ?? mostRecentWindow(of: parked, pid: pid)
        {
            return .window(id)
        }
        if let id = mostRecentWindow(of: elsewhere, pid: pid) {
            return .unmovable(id)
        }
        if !open.isEmpty { return .allHere }
        // Without text every window matches, so the app has none.
        return text.map { .noMatch(text: $0) } ?? .noWindow
    }

    /// Whether `title` contains `text`, case-, accent- and
    /// width-insensitive — a title changes, so never an exact match.
    static func titleMatches(_ title: String, _ text: String) -> Bool {
        title.range(
            of: text,
            options: [
                .caseInsensitive, .diacriticInsensitive,
                .widthInsensitive,
            ]
        ) != nil
    }

    /// An away window, or a tracked one not in native full screen.
    private func movableHere(_ id: WindowID) -> Bool {
        state.windows[id]?.isFullscreen != true
    }

    /// In `active` already, or a sticky window rendering there.
    private func isDrawnHere(_ id: WindowID, _ active: SpaceID) -> Bool {
        guard let window = state.windows[id] else { return false }
        return state.workspaces.space(of: id) == active
            || state.stickyRenderSpace(of: window) == active
    }

    private func appName(_ bundleID: String) -> String {
        state.windows.all.first {
            $0.appBundleID?.lowercased() == bundleID
        }?.appName
            ?? state.minimizeOrder.first {
                $0.bundleID?.lowercased() == bundleID
            }?.app ?? bundleID
    }

    /// The pill draws on the focused window, the one being looked at.
    private func cueMoveHere(_ refusal: WindowActionRefusal) {
        guard let focused = state.workspaces.lastFocused else {
            onLog("move_here: \(refusal.logReason)")
            return
        }
        cueWindowAction(refusal, on: focused)
    }
}
