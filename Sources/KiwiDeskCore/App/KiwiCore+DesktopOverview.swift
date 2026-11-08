import AppKit

/// KiwiHub's Desktops side (#1229): one reading of the whole desk.
/// A Desktop a screen shows lists its Spaces' members from state; a
/// hidden one lists the away ledger's UP windows on it (#1146),
/// each in the Space it will return to. KiwiDesk keeps no Space set
/// per Desktop (`KiwiCore+DesktopSpaces.swift`), so every Desktop
/// of a screen lists that screen's live Spaces. Read once when the
/// side opens; the panel keeps the reading.
extension KiwiCore {
    /// `display` is the screen KiwiHub opened on, its row's "here".
    public func desktopOverview(on display: DisplayID?) -> DesktopOverview {
        let snapshot = desktopMemory.readDesktops()
        let byUUID = displaysByUUID()
        let main = PositionalDisplays.liveMainID
        let screens = Self.physicalOrder(state.workspaces.allDisplays)
            .map { screen in
                let uuid = byUUID.first { $0.value.id == screen.id }?.key
                return DesktopOverview.Screen(
                    display: screen.id,
                    name: screen.name,
                    isMain: screen.id == main,
                    isHere: screen.id == display,
                    desktops: overviewDesktops(
                        on: screen.id,
                        uuid: uuid,
                        in: snapshot,
                        shared: snapshot.soleDisplayKey.map {
                            byUUID[$0] == nil
                        } ?? false
                    )
                )
            }
        return DesktopOverview(screens: screens, yours: jumpFocusedWindow())
    }

    /// Left to right, then top to bottom: System Settings ▸
    /// Displays' arrangement read as rows. AppKit's y grows UP, so
    /// the screen above has the larger `minY`.
    static func physicalOrder(_ displays: [Display]) -> [Display] {
        displays.sorted { lhs, rhs in
            if lhs.frame.minX != rhs.frame.minX {
                return lhs.frame.minX < rhs.frame.minX
            }
            if lhs.frame.minY != rhs.frame.minY {
                return lhs.frame.minY > rhs.frame.minY
            }
            return lhs.fingerprint < rhs.fingerprint
        }
    }

    /// A screen's user Desktops in Mission Control order. With
    /// "Displays have separate Spaces" off every screen lists the
    /// one shared set; without SkyLight, the one Desktop it shows.
    private func overviewDesktops(
        on display: DisplayID,
        uuid: String?,
        in snapshot: DesktopSnapshot,
        shared: Bool
    ) -> [DesktopOverview.Desktop] {
        let natives = snapshot.spaces.filter {
            $0.isUser && (shared || $0.displayUUID == uuid)
        }
        guard !natives.isEmpty else {
            return [
                DesktopOverview.Desktop(
                    native: 0,
                    label: 1,
                    number: nil,
                    isShown: true,
                    profile: nil,
                    spaces: shownLines(on: display)
                )
            ]
        }
        return natives.enumerated().map { index, native in
            let shown =
                snapshot.currentSpaces[native.displayUUID].map {
                    $0 == native.id
                } ?? native.isCurrent
            return DesktopOverview.Desktop(
                native: native.id,
                label: snapshot.screenNumber(of: native.id) ?? index + 1,
                number: snapshot.number(of: native.id),
                isShown: shown,
                profile: boundProfileLabel(of: native.id, in: snapshot),
                spaces: shown
                    ? shownLines(on: display)
                    : hiddenLines(on: display, native: native, in: snapshot)
            )
        }
    }

    /// The label of the profile a Desktop's binding would load,
    /// read off the binding's own rank without opening a file.
    private func boundProfileLabel(
        of native: SkyLight.SpaceID,
        in snapshot: DesktopSnapshot
    ) -> String? {
        let binding = snapshot.keys(of: native).lazy
            .compactMap { self.desktopBindings[$0] }.first
        return binding?.ranked(
            for: liveFingerprints,
            preferring: liveProfileRef
        ).first?.name
    }

    /// The Spaces of a screen on the Desktop it shows.
    private func shownLines(on display: DisplayID) -> [DesktopOverview
        .SpaceLine]
    {
        let active = state.workspaces.activeSpace(on: display)
        return state.workspaces.spaces(on: display).map { id in
            let space = state.workspaces[id]
            let members = space.map(state.effectiveMembers(of:)) ?? []
            return overviewLine(
                id,
                isShown: id == active,
                windows: members.compactMap { member in
                    state.windows[member].map(overviewWindow)
                },
                lastFocused: space.flatMap(state.focusAnchor(of:))
            )
        }
    }

    /// A hidden Desktop's Spaces: the away windows up on it, each
    /// in its remembered Space, and those no Space holds last.
    private func hiddenLines(
        on display: DisplayID,
        native: NativeSpace,
        in snapshot: DesktopSnapshot
    ) -> [DesktopOverview.SpaceLine] {
        let away = state.awayWindows.values
            .filter { $0.isUp && $0.nativeSpace == native.id }
            .sorted { $0.id.raw < $1.id.raw }
        let returning = snapshot.keys(of: native.id).lazy
            .compactMap { self.desktopMemory.virtualSpaces[$0] }.first
        let spaces = state.workspaces.spaces(on: display)
        var lines = spaces.map { id in
            overviewLine(
                id,
                isShown: id == returning,
                windows:
                    away
                    .filter { state.rememberedSpace(of: $0.id) == id }
                    .map(awayOverviewWindow),
                lastFocused: desktopMemory.honoredFocus[id]?[native.id]
            )
        }
        let unfiled = away.filter { entry in
            state.rememberedSpace(of: entry.id).map {
                !spaces.contains($0)
            } ?? true
        }
        if !unfiled.isEmpty {
            lines.append(
                DesktopOverview.SpaceLine(
                    space: nil,
                    glyph: nil,
                    mode: nil,
                    isShown: false,
                    marker: nil,
                    windows: unfiled.map(awayOverviewWindow),
                    lastFocused: nil
                )
            )
        }
        return lines
    }

    private func overviewLine(
        _ id: SpaceID,
        isShown: Bool,
        windows: [DesktopOverview.Window],
        lastFocused: WindowID?
    ) -> DesktopOverview.SpaceLine {
        let marker: DesktopOverview.Marker? =
            state.heldSpaces[id] != nil
            ? .held : isTemporary(id) ? .temporary : nil
        return DesktopOverview.SpaceLine(
            space: id,
            glyph: spaceGlyph(for: id),
            mode: state.workspaces[id]?.mode,
            isShown: isShown,
            marker: marker,
            windows: windows,
            lastFocused: lastFocused
        )
    }

    private func overviewWindow(
        _ window: ManagedWindow
    ) -> DesktopOverview.Window {
        DesktopOverview.Window(
            id: window.id,
            pid: window.pid,
            app: window.appName,
            title: window.title,
            block: window.isFullscreen ? .fullScreen : nil
        )
    }

    private func awayOverviewWindow(
        _ entry: AwayWindow
    ) -> DesktopOverview.Window {
        DesktopOverview.Window(
            id: entry.id,
            pid: entry.pid,
            app: entry.appName,
            title: entry.title,
            block: .otherDesktop
        )
    }
}
