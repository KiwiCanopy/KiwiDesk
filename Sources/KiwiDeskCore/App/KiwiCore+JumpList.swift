import AppKit

/// The rows of Jump to window (#1875): every window KiwiDesk
/// knows — tracked, up on an away Desktop, or minimized — most
/// recently used first, then one row per hidden app. Read once
/// when the panel opens; the panel keeps that snapshot.
extension KiwiCore {
    public func jumpEntries() -> [JumpEntry] {
        let windows =
            trackedJumpEntries() + awayJumpEntries()
            + minimizedJumpEntries()
        let ordered = windows.enumerated().sorted { lhs, rhs in
            let left = jumpRecency(lhs.element)
            let right = jumpRecency(rhs.element)
            return left != right ? left > right : lhs.offset < rhs.offset
        }
        return ordered.map(\.element) + hiddenAppJumpEntries()
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
                    status: window.isFullscreen ? .fullscreen : .shown
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
                status: .away(desktop: snapshot.number(of: entry.nativeSpace))
            )
        }
    }

    private func minimizedJumpEntries() -> [JumpEntry] {
        state.minimizeOrder.reversed().map { record in
            JumpEntry(
                target: .window(record.id),
                pid: record.pid,
                app: record.app,
                title: record.title,
                space: nil,
                spaceIcon: nil,
                status: .minimized
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
                app.activationPolicy == .regular
                    && !EventLoop.isOwnProcess(app.pid)
                    && eventLoop.appIsHidden(app.pid)
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
                    status: .hidden
                )
            }
    }

    /// The Space's own icon, nil without one — the id alone is
    /// the name the panel already shows.
    private func jumpSpaceIcon(_ space: SpaceID) -> SpaceGlyph? {
        guard let icon = tiler.settings.spaceIcons[space], !icon.isEmpty
        else { return nil }
        return Self.iconGlyph(icon)
    }
}
