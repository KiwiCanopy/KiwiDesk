import Foundation
import Testing

@testable import KiwiDeskCore

/// The `layer_change` event (#1168): the active keyboard layer's
/// switch reaches Lua and the IPC stream, carrying the previous
/// and the new layer. The one-door clause over the manager's
/// source is `LayerChangeSeamTests`, in the GUI target where
/// the scanners live.
@Suite("layer_change event (#1168)", .serialized)
@MainActor
struct LayerChangeEventTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-layer-event-\(UUID().uuidString)"
                )
        )
    }

    private func layerEvents(
        _ events: [(KiwiNotification, JSONValue)]
    ) -> [[String: JSONValue]] {
        events.compactMap { event, data in
            guard event == .layerChange,
                case .object(let payload) = data
            else { return nil }
            return payload
        }
    }

    /// A switch carries `from` and `to` on the sink, and the same
    /// pair positionally to a Lua subscriber.
    @Test("a switch emits from and to, on both channels")
    func switchEmits() throws {
        let core = makeCore()
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try """
        KiwiDesk.on("layer_change", function(from, to)
            seen = from .. ">" .. to
        end)
        """
        .write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        // Defined after the load: a config with no managed
        // setting seeds gui.json, whose structured layers would
        // replace one declared in Lua.
        core.keys.defineLayer("resize", bindings: [:])
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { events.append(($0, $1)) }

        core.keys.switchLayer("resize")
        let payloads = layerEvents(events)
        #expect(payloads.count == 1)
        #expect(payloads.first?["from_layer"] == .string("default"))
        #expect(payloads.first?["to_layer"] == .string("resize"))
        #expect(core.lua?.global("seen") == .string("default>resize"))

        core.keys.switchLayer("default")
        #expect(layerEvents(events).count == 2)
        #expect(
            layerEvents(events).last?["to_layer"] == .string("default")
        )
        #expect(core.lua?.global("seen") == .string("resize>default"))
    }

    /// No change, no event: a switch to the layer already active
    /// and a switch to an unknown layer both stay silent.
    @Test("a no-op switch emits nothing")
    func noOpStaysSilent() {
        let core = makeCore()
        core.keys.defineLayer("resize", bindings: [:])
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { events.append(($0, $1)) }

        core.keys.switchLayer("default")
        #expect(layerEvents(events).isEmpty)
        core.keys.switchLayer("nope")
        #expect(layerEvents(events).isEmpty)
        #expect(core.keys.currentLayer == "default")
    }

    /// A config reload drops the layers and returns to `default`
    /// — a switch the user did not press, reported to the SINKS
    /// like any other; the Lua side has just lost its callbacks,
    /// so this channel is the IPC stream's.
    @Test("a reset from a layer reports the return to default")
    func resetReports() {
        let core = makeCore()
        core.keys.defineLayer("resize", bindings: [:])
        core.keys.switchLayer("resize")
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { events.append(($0, $1)) }

        core.keys.reset()
        let payloads = layerEvents(events)
        #expect(payloads.count == 1)
        #expect(payloads.first?["from_layer"] == .string("resize"))
        #expect(payloads.first?["to_layer"] == .string("default"))
        // …and a reset already on `default` reports nothing.
        core.keys.reset()
        #expect(layerEvents(events).count == 1)
    }
}
