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
            let shown = Self.isShown(native.id, in: snapshot)
            return DesktopOverview.Desktop(
                native: native.id,
                label: snapshot.number(of: native.id) ?? index + 1,
                number: snapshot.number(of: native.id),
                isShown: shown,
                profile: boundProfileLabel(of: native.id, in: snapshot),
                spaces: shown
                    ? shownLines(on: display)
                    : hiddenLines(
                        on: display,
                        native: native,
                        in: snapshot,
                        shared: shared
                    )
            )
        }
    }

    /// The profile a Desktop's binding loads, picked by the one
    /// gate (profiles.md ▸ readers follow the pick); nil where none
    /// is bound or the binding stands aside.
    private func boundProfileLabel(
        of native: SkyLight.SpaceID,
        in snapshot: DesktopSnapshot
    ) -> String? {
        let binding = snapshot.keys(of: native).lazy
            .compactMap { self.desktopBindings[$0] }.first
        guard let binding, case .success(let pick) = boundProfile(of: binding)
        else { return nil }
        return pick.profile.name
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
        in snapshot: DesktopSnapshot,
        shared: Bool
    ) -> [DesktopOverview.SpaceLine] {
        let onDesktop: (WindowID) -> AwayWindow? = { id in
            self.state.awayWindows[id].flatMap {
                $0.nativeSpace == native.id ? $0 : nil
            }
        }
        let returning = rememberedVirtualSpace(of: native.id, in: snapshot)
        let spaces = state.workspaces.spaces(on: display)
        var lines = spaces.map { id in
            overviewLine(
                id,
                isShown: id == returning,
                // The ledger's own reader, in the rank they return in.
                windows: awayMembers(of: id).compactMap(onDesktop)
                    .map(awayOverviewWindow),
                lastFocused: desktopMemory.honoredFocus[id]?[native.id]
            )
        }
        // Only what no screen's Space will take back: with shared
        // Desktops each screen lists the set, and a window filed on
        // another screen is listed there.
        let unfiled = state.awayWindows.values
            .filter { $0.isUp && $0.nativeSpace == native.id }
            .filter { entry in
                state.rememberedSpace(of: entry.id).map {
                    !spaces.contains($0)
                        && !(shared && state.workspaces.display(of: $0) != nil)
                } ?? true
            }
            .sorted { $0.id.raw < $1.id.raw }
        if !unfiled.isEmpty {
            lines.append(
                DesktopOverview.SpaceLine(
                    space: nil,
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
            switch spaceMarker(of: id) {
            case .held?: .held
            case .temporary?: .temporary
            case nil: nil
            }
        return DesktopOverview.SpaceLine(
            space: id,
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
            block: nil
        )
    }
}
