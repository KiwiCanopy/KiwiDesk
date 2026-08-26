import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

@Suite("Command execution", .serialized)
@MainActor
struct CommandTests {
    @Test("set_mode changes the space layout and emits")
    func setMode() {
        let core = makeCore()
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { event, data in
            events.append((event, data))
        }
        let response = core.execute(
            "set_mode",
            args: [.string("2"), .string("stack")]
        )
        #expect(response.isSuccess)
        #expect(
            core.state.workspaces[SpaceID(2)]?.mode == .stack
        )
        #expect(events.contains { $0.0 == .layoutChange })
    }

    @Test("set_gap_global updates tiling settings")
    func gaps() {
        let core = makeCore()
        #expect(
            core.execute(
                "set_gap_global",
                args: [.number(24)]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.gapsGlobal
                == .uniform(24)
        )
        #expect(
            core.execute(
                "set_gap_override",
                args: [.string("3"), .number(0)]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.gaps(for: SpaceID(3))
                == .uniform(0)
        )
    }

    @Test("Layout sub-APIs adjust parameters")
    func subAPIs() {
        let core = makeCore()
        #expect(
            core.execute(
                "stack.set_master_count",
                args: [.number(2)]
            ).isSuccess
        )
        #expect(core.tiler.settings.stack.masterCount == 2)

        #expect(
            core.execute(
                "bsp.set_strategy",
                args: [.string("alternating")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.bsp.strategy == .alternating
        )

        #expect(
            core.execute(
                "grid.set_dimensions",
                args: [.number(4), .number(2)]
            ).isSuccess
        )
        #expect(core.tiler.settings.grid.columns == 4)
        #expect(core.tiler.settings.grid.rows == 2)
    }

    @Test("Unknown commands return an error with a hint")
    func unknownCommand() {
        let core = makeCore()
        let response = core.execute("frobnicate")
        #expect(!response.isSuccess)
        #expect(response.error?.contains("unknown") == true)
        #expect(response.error?.contains("help") == true)
    }

    @Test("Typos get a did-you-mean suggestion")
    func didYouMean() {
        let core = makeCore()
        let response = core.execute("set_mdoe")
        #expect(
            response.error?.contains("set_mode") == true
        )
    }

    @Test("help lists every command, in its group")
    func helpCommand() {
        // Grouped since #1033; the flat array of names this
        // used to read is what the issue was filed about.
        let core = makeCore()
        let response = core.execute("help")
        guard case .object(let payload)? = response.data,
            case .array(let groups)? = payload["groups"]
        else {
            Issue.record("expected grouped command list")
            return
        }
        var listed: [String: String] = [:]
        for case .object(let group) in groups {
            guard case .array(let commands)? = group["commands"]
            else { continue }
            for case .object(let entry) in commands {
                guard
                    let name = entry["qualified_name"]?
                        .stringValue,
                    let table = group["name"]?.stringValue
                else { continue }
                listed[name] = table
            }
        }
        #expect(listed["focus"] == "KiwiDesk")
        #expect(listed["stack.set_master_count"] == "stack")
        #expect(listed["subscribe"] == "KiwiDesk")
        #expect(listed["version"] == "KiwiDesk")
    }

    @Test("version reports the semantic version and commit")
    func versionCommand() {
        let core = makeCore()
        let response = core.execute("version")
        guard case .object(let data)? = response.data else {
            Issue.record("expected object data")
            return
        }
        #expect(
            data["version"]
                == .string(KiwiDeskVersion.semantic)
        )
        #expect(
            data["commit"] == .string(KiwiDeskVersion.commit)
        )
    }

    @Test("get_state reports spaces and windows")
    func getState() {
        let events = makeCore()
        events.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(7),
                    pid: 1,
                    appName: "Editor",
                    appBundleID: "com.example.editor"
                )
            )
        )
        let response = events.execute("get_state")
        guard case .object(let data)? = response.data else {
            Issue.record("expected object data")
            return
        }
        #expect(data["active_space"] == .string("1"))
        guard case .array(let windows)? = data["windows"]
        else {
            Issue.record("expected windows array")
            return
        }
        #expect(windows.count == 1)
        // The bundle id is surfaced so a power user can read
        // off the value app rules / pull_or_spawn take (#262).
        guard case .object(let window)? = windows.first else {
            Issue.record("expected window object")
            return
        }
        #expect(
            window["bundle_id"] == .string("com.example.editor")
        )
    }
}
