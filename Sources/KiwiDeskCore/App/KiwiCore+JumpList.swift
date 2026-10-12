import AppKit

/// The rows of Jump to window (#1875): every window KiwiDesk
/// knows — tracked, up on an away Desktop, or minimized — most
/// recently used first, then one row per hidden app. The focused
/// window is left out: neither a jump nor Move here does anything
/// for the window the user is in (owner, 2026-10-12). Read once
/// when the panel opens; the panel keeps that snapshot.
extension KiwiCore {
    public func jumpSnapshot() -> JumpSnapshot {
        let here = state.workspaces.activeSpace
        return JumpSnapshot(
            entries: jumpEntries(),
            here: here,
            hereIcon: here.flatMap(jumpSpaceIcon)
        )
    }

    func jumpEntries() -> [JumpEntry] {
        let windows =
            trackedJumpEntries() + awayJumpEntries()
            + minimizedJumpEntries()
        let ordered = windows.enumerated().sorted { lhs, rhs in
            let left = jumpRecency(lhs.element)
            let right = jumpRecency(rhs.element)
            return left != right ? left > right : lhs.offset < rhs.offset
        }
        let focused = jumpFocusedWindow().map {
            JumpEntry.Target.window($0)
        }
        return ordered.map(\.element).filter { $0.target != focused }
            + hiddenAppJumpEntries()
    }

    /// The window the user is in: the bar's focus, only while its
    /// app is the one in front — a sibling process included (#1785).
    /// `lastFocused` outlives a move to an app KiwiDesk does not
    /// track, whose last window is then the one the user most
    /// likely wants back.
    private func jumpFocusedWindow() -> WindowID? {
        guard let id = barFocus(on: nil),
            let pid = state.windows[id]?.pid,
            frontmostOwns(pid: pid)
        else { return nil }
        return id
    }

    /// The most recent honored focus first; a window never focused
    /// keeps its gathering order behind every stamped one.
    private func jumpRecency(_ entry: JumpEntry) -> UInt64 {
        guard case .window(let id) = entry.target else { return 0 }
        return state.focusRecencyRank(of: id)
    }

    private func trackedJumpEntries() -> [JumpEntry] {
        state.windows.all
            .filter { !$0.isTransientOverlay }
            .sorted { $0.id.raw < $1.id.raw }
            .map { window in
                let space = state.workspaces.space(of: window.id)
                return JumpEntry(
                    target: .window(window.id),
                    pid: window.pid,
                    app: window.appName,
                    title: window.title,
                    space: space,
                    spaceIcon: space.flatMap(jumpSpaceIcon),
                    status: window.isFullscreen ? .fullscreen : .shown,
                    movesHere: jumpMovesHere(window, from: space)
                )
            }
    }

    /// The away ledger's UP entries — a window parked while away is
    /// not reachable (#1146). The Desktop number comes from ONE
    /// topology reading, taken only when there is an entry.
    private func awayJumpEntries() -> [JumpEntry] {
        let away = state.awayWindows.values
            .filter(\.isUp)
            .sorted { $0.id.raw < $1.id.raw }
        guard !away.isEmpty else { return [] }
        let snapshot = NativeSpaces.desktopSnapshot()
        return away.map { entry in
            let space = state.rememberedSpace(of: entry.id)
            return JumpEntry(
                target: .window(entry.id),
                pid: entry.pid,
                app: entry.appName,
                title: entry.title,
                space: space,
                spaceIcon: space.flatMap(jumpSpaceIcon),
                status: .away(desktop: snapshot.number(of: entry.nativeSpace)),
                movesHere: canDriveDesktops && entry.appBundleID != nil
                    && state.workspaces.activeSpace != nil
            )
        }
    }

    /// The minimize record is advisory: a window closed while
    /// minimized fires no event, so a record the WindowServer no
    /// longer lists is left out. No reading keeps every record.
    private func minimizedJumpEntries() -> [JumpEntry] {
        let known = jump.knownWindows()
        return state.minimizeOrder.reversed().filter { record in
            known.map { $0.contains(record.id) } ?? true
        }.map { record in
            JumpEntry(
                target: .window(record.id),
                pid: record.pid,
                app: record.app,
                title: record.title,
                space: nil,
                spaceIcon: nil,
                status: .minimized,
                movesHere: state.workspaces.activeSpace != nil
            )
        }
    }

    /// One row per hidden regular app, by name: KiwiDesk drops a
    /// hidden app's windows (#913), so it knows no titles to list.
    /// No window owners handed in: a hidden app is always on
    /// LaunchServices' list, so the census read would buy nothing.
    private func hiddenAppJumpEntries() -> [JumpEntry] {
        eventLoop.liveApps(owners: [])
            .filter { app in
                app.isHidden && !EventLoop.isOwnProcess(app.pid)
                    && eventLoop.policy(of: app.pid) == .regular
            }
            .sorted {
                $0.ref.name.localizedStandardCompare($1.ref.name)
                    == .orderedAscending
            }
            .map { app in
                JumpEntry(
                    target: .hiddenApp(app.pid),
                    pid: app.pid,
                    app: app.ref.name,
                    title: "",
                    space: nil,
                    spaceIcon: nil,
                    status: .shown
                )
            }
    }

    /// Whether `moveHere(_:)` would move a tracked window: not a
    /// full-screen one, not one already here, and not one the
    /// sticky gate holds — a ∞ window, already drawn here, is only
    /// focused. An away row asks the bridge and its bundle id, the
    /// hop's gates known ahead of it: whether it reaches is known
    /// only when it runs.
    private func jumpMovesHere(
        _ window: ManagedWindow,
        from space: SpaceID?
    ) -> Bool {
        guard let active = state.workspaces.activeSpace,
            !window.isFullscreen, space != active
        else { return false }
        return stickyMoveBlock(window.id, to: active) == nil
    }

    /// The Space's own icon, the bar chip's reading, nil without
    /// one — the id alone is the name the panel already shows.
    private func jumpSpaceIcon(_ space: SpaceID) -> SpaceGlyph? {
        configuredSpaceIcon(of: space).map(Self.iconGlyph)
    }
}
