import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The owner's desk the held-Space suites replay (#1507): a
/// built-in screen and a DELL. `desk` covers both, with Spaces 3
/// and 4 pinned to the DELL; `solo` covers the built-in and
/// declares 1–3.
@MainActor
struct HeldSpaceDesk {
    let builtIn = Display(
        id: DisplayID(1),
        name: "BUILTIN",
        frame: CGRect(x: 0, y: 0, width: 100, height: 100)
    )
    let dell = Display(
        id: DisplayID(3),
        name: "DELL",
        frame: CGRect(x: 100, y: 0, width: 200, height: 100)
    )

    func profile(
        _ name: String,
        screens: [String],
        spaces: [SpaceID],
        pins: [SpaceID: String] = [:]
    ) -> Profile {
        var modes: [SpaceID: LayoutMode] = [:]
        for space in spaces { modes[space] = .bsp }
        return Profile(
            name: name,
            monitorSets: [
                MonitorSet(monitors: screens, spaceMonitorMap: pins)
            ],
            spaces: spaces,
            spaceModes: modes,
            settings: TilingSettings()
        )
    }

    /// Docked on `desk`: window 13 in Space 1, 10 and 11 in the
    /// DELL's 3, 12 in the DELL's 4.
    func docked() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-1507-\(UUID().uuidString)"
                )
        )
        let dellPin = dell.fingerprint
        try core.profiles.save(
            profile(
                "solo",
                screens: [builtIn.fingerprint],
                spaces: [SpaceID(1), SpaceID(2), SpaceID(3)]
            )
        )
        try core.profiles.save(
            profile(
                "desk",
                screens: [builtIn.fingerprint, dellPin],
                spaces: [SpaceID(1), SpaceID(2), SpaceID(3), SpaceID(4)],
                pins: [SpaceID(3): dellPin, SpaceID(4): dellPin]
            )
        )
        core.handle(.displaysChanged([builtIn, dell]))
        core.execute("load_profile", args: [.string("desk")])
        #expect(core.profiles.currentName == "desk")
        for (id, space) in [(13, 1), (10, 3), (11, 3), (12, 4)] {
            let window = WindowID(UInt32(id))
            core.state.windows.upsert(
                ManagedWindow(id: window, pid: 1, appName: "App\(id)")
            )
            core.state.workspaces.add(window, to: SpaceID(space))
        }
        return core
    }

    /// Docked on a `wide` desk whose DELL carries `dellSpaces`,
    /// one window each (100, 101, …), beside `solo`'s 1–3.
    func docked(dellSpaces: [SpaceID]) throws -> KiwiCore {
        let core = try docked()
        let dellPin = dell.fingerprint
        var pins: [SpaceID: String] = [:]
        for space in dellSpaces { pins[space] = dellPin }
        // Written, not saved: a save adopts it, and the load below
        // must be a switch rather than a same-profile Load (#1790).
        try core.profiles.write(
            profile(
                "wide",
                screens: [builtIn.fingerprint, dellPin],
                spaces: [SpaceID(1), SpaceID(2)] + dellSpaces,
                pins: pins
            )
        )
        // `wide` does not name desk's DELL Spaces, so the load would
        // hold them with their windows (#1790): hand those to 1.
        for id in [10, 11, 12] {
            core.state.workspaces.add(WindowID(UInt32(id)), to: SpaceID(1))
        }
        core.execute("load_profile", args: [.string("wide")])
        for (offset, space) in dellSpaces.enumerated() {
            let window = WindowID(UInt32(100 + offset))
            core.state.windows.upsert(
                ManagedWindow(id: window, pid: 1, appName: "W\(offset)")
            )
            core.state.workspaces.add(window, to: space)
        }
        #expect(core.profiles.currentName == "wide")
        return core
    }

    /// Window `id` as the desk's apps show it.
    func window(_ id: Int) -> ManagedWindow {
        ManagedWindow(id: WindowID(UInt32(id)), pid: 1, appName: "App\(id)")
    }

    /// A built-in profile declaring 1–5, so it claims the held 5.
    func fiveSpaces() -> Profile {
        profile(
            "five",
            screens: [builtIn.fingerprint],
            spaces: (1...5).map { SpaceID($0) }
        )
    }

    func members(_ core: KiwiCore, _ space: Int) -> [WindowID] {
        core.state.workspaces[SpaceID(space)]?.windows ?? []
    }

    func ids(_ raw: [Int]) -> [WindowID] {
        raw.map { WindowID(UInt32($0)) }
    }
}
