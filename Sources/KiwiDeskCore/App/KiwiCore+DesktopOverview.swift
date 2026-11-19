import AppKit

/// KiwiHub's Desktops side (#1229): one reading of the whole desk.
/// A Desktop a screen shows lists its Spaces' members from state; a
/// hidden one lists the away ledger's UP windows on it (#1146),
/// each in the Space it will return to. A window in macOS full
/// screen lists on its Space's line wherever it is (#3486).
/// KiwiDesk keeps no Space set per Desktop
/// (`KiwiCore+DesktopSpaces.swift`), so every Desktop of a screen
/// lists that screen's live Spaces. Read once when the side opens;
/// the panel keeps the reading.
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
                        shared: sharedDesktops(in: snapshot)
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
        let fullScreen = fullScreenAway(
            on: uuid,
            in: snapshot,
            shared: shared
        )
        let held = heldDesktop(on: display, in: snapshot)
        guard !natives.isEmpty else {
            return [
                DesktopOverview.Desktop(
                    native: 0,
                    label: 1,
                    number: nil,
                    isShown: true,
                    profile: nil,
                    spaces: shownLines(
                        on: display,
                        adding: fullScreen,
                        in: snapshot,
                        shared: shared
                    )
                )
            ]
        }
        return natives.enumerated().map { index, native in
            let shown = Self.isShown(native.id, in: snapshot)
            let holds = !shown && native.id == held
            return DesktopOverview.Desktop(
                native: native.id,
                label: snapshot.number(of: native.id) ?? index + 1,
                number: snapshot.number(of: native.id),
                isShown: shown,
                holdsLive: holds,
                profile: boundProfileLabel(of: native.id, in: snapshot),
                spaces: shown
                    ? shownLines(
                        on: display,
                        adding: fullScreen,
                        in: snapshot,
                        shared: shared
                    )
                    : hiddenLines(
                        on: display,
                        native: native,
                        in: snapshot,
                        shared: shared,
                        live: holds ? fullScreen : nil
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

    /// The Spaces of a screen on the Desktop it shows, with the
    /// screen's away full-screen windows on their Spaces' lines.
    private func shownLines(
        on display: DisplayID,
        adding fullScreen: [AwayWindow],
        in snapshot: DesktopSnapshot,
        shared: Bool
    ) -> [DesktopOverview.SpaceLine] {
        let active = state.workspaces.activeSpace(on: display)
        let spaces = state.workspaces.spaces(on: display)
        let lines = spaces.map { id in
            overviewLine(
                id,
                isShown: id == active,
                windows: liveMembers(of: id)
                    + awayWindows(fullScreen, in: id, snapshot),
                lastFocused: state.workspaces[id]
                    .flatMap(state.focusAnchor(of:))
            )
        }
        let unfiled = fullScreen.filter {
            self.unfiled($0, outside: spaces, shared: shared)
        }
        return lines + unfiledLine(unfiled, snapshot)
    }

    /// A Space's live members as the overview lists them.
    private func liveMembers(of id: SpaceID) -> [DesktopOverview.Window] {
        let members = state.workspaces[id].map(state.effectiveMembers(of:))
        return (members ?? []).compactMap { member in
            state.windows[member].map(overviewWindow)
        }
    }

    /// A hidden Desktop's Spaces: the away windows up on it, each
    /// in its remembered Space, and those no Space holds last. The
    /// Desktop the live Spaces hold while a full-screen Space is in
    /// front takes `live`, the screen's away full-screen windows,
    /// and lists its live members first (#3486).
    private func hiddenLines(
        on display: DisplayID,
        native: NativeSpace,
        in snapshot: DesktopSnapshot,
        shared: Bool,
        live: [AwayWindow]?
    ) -> [DesktopOverview.SpaceLine] {
        let onDesktop: (WindowID) -> AwayWindow? = { id in
            self.state.awayWindows[id].flatMap {
                $0.nativeSpace == native.id ? $0 : nil
            }
        }
        let returning = rememberedVirtualSpace(of: native.id, in: snapshot)
        let active = state.workspaces.activeSpace(on: display)
        let spaces = state.workspaces.spaces(on: display)
        var lines = spaces.map { id in
            overviewLine(
                id,
                isShown: id == (live == nil ? returning : active),
                // The ledger's own reader, in the rank they return in.
                windows: (live == nil ? [] : liveMembers(of: id))
                    + awayWindows(
                        awayMembers(of: id).compactMap(onDesktop)
                            + (live ?? []),
                        in: id,
                        snapshot
                    ),
                lastFocused: live == nil
                    ? desktopMemory.honoredFocus[id]?[native.id]
                    : state.workspaces[id].flatMap(state.focusAnchor(of:))
            )
        }
        // Only what no screen's Space will take back: with shared
        // Desktops each screen lists the set, and a window filed on
        // another screen is listed there.
        let unfiled =
            state.awayWindows.values
            .filter { $0.isUp && $0.nativeSpace == native.id }
            .sorted { $0.id.raw < $1.id.raw }
            + (live ?? [])
        return lines
            + unfiledLine(
                unfiled.filter {
                    self.unfiled($0, outside: spaces, shared: shared)
                },
                snapshot
            )
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
}
