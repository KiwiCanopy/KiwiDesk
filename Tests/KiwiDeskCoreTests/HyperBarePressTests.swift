import Carbon.HIToolbox
import Foundation
import Testing

@testable import KiwiDeskCore

/// A registrar that records what is registered right now and
/// reports releases like Carbon does.
@MainActor
private final class LiveRegistrar: HotkeyRegistrar,
    HotkeyReleaseReporting
{
    var onRelease: @MainActor (UInt32) -> Void = { _ in }
    var live: [UInt32: (code: UInt32, mask: UInt32, fire: () -> Void)] =
        [:]
    private var nextID: UInt32 = 1

    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? {
        defer { nextID += 1 }
        live[nextID] = (keyCode, modifiers.carbonMask, handler)
        return nextID
    }

    func unregister(id: UInt32) { live[id] = nil }

    func has(_ code: UInt32) -> Bool {
        live.values.contains { $0.code == code && $0.mask == 0 }
    }

    func press(_ code: UInt32) {
        live.values.first { $0.code == code && $0.mask == 0 }?.fire()
    }

    func release(_ code: UInt32) {
        for (id, entry) in live where entry.code == code {
            onRelease(id)
        }
    }
}

/// Hyper with no Hyper row in the active layer (#2480): the trigger
/// still catches F18, so the frontmost app never beeps, and a press
/// reports itself once per hold so the core can say why.
@MainActor
@Suite("Hyper bare press")
struct HyperBarePressTests {
    private let f18 = HyperSourceKey.triggerKeyCode

    private func manager(
        _ registrar: HotkeyRegistrar,
        combos: [String]
    ) throws -> KeybindingManager {
        let keys = KeybindingManager(registrar: registrar)
        keys.onLog = { _ in }
        var layer: [KeyCombo: Int32] = [:]
        for (index, spelling) in combos.enumerated() {
            layer[try #require(KeyCombo.parse(spelling))] = Int32(index + 1)
        }
        keys.replaceLayers(
            [KeybindingManager.defaultLayer: layer],
            icons: [:],
            preferredLayer: KeybindingManager.defaultLayer
        )
        keys.hyperEnabled = true
        return keys
    }

    @Test("Hyper with no Hyper row still catches the key")
    func triggerArmsWithoutRows() throws {
        let registrar = LiveRegistrar()
        let keys = try manager(registrar, combos: ["ctrl+j"])
        #expect(registrar.has(f18))
        #expect(!keys.hyperHasShortcuts)
        keys.hyperEnabled = false
        #expect(!registrar.has(f18))
    }

    @Test("a bare press reports once per hold")
    func barePressReportsOncePerHold() throws {
        let registrar = LiveRegistrar()
        let keys = try manager(registrar, combos: ["ctrl+j"])
        var reports = 0
        keys.onBareHyper = { reports += 1 }
        registrar.press(f18)
        registrar.press(f18)  // key repeat inside one hold
        #expect(reports == 1)
        registrar.release(f18)
        registrar.press(f18)
        #expect(reports == 2)
    }

    @Test("a layer with a Hyper row reports nothing")
    func rowsReportNothing() throws {
        let registrar = LiveRegistrar()
        let keys = try manager(registrar, combos: ["hyper+h"])
        var reports = 0
        keys.onBareHyper = { reports += 1 }
        #expect(keys.hyperHasShortcuts)
        registrar.press(f18)
        #expect(reports == 0)
    }
}

/// The core's side (#2480): wired once at bootstrap, and the cue is
/// silent by ruling, since the beep was the defect.
@Suite("Hyper bare press wiring")
struct HyperBarePressWiringTests {
    private static func source(_ path: String) throws -> String {
        try String(
            contentsOf: scriptFixtureRepoRoot().appendingPathComponent(
                "Sources/KiwiDeskCore/" + path
            ),
            encoding: .utf8
        )
    }

    @Test("bootstrap wires the bare press to the cue")
    func wired() throws {
        let boot = try Self.source("App/KiwiCore+Bootstrap.swift")
        #expect(
            boot.contains(
                "keys.onBareHyper = { [weak self] in self?.cueBareHyper() }"
            )
        )
    }

    @Test("the cue draws a pill, announces it and never sounds")
    func silentAndAnnounced() throws {
        let cue = try Self.source("App/KiwiCore+HyperBarePress.swift")
        #expect(cue.contains("flashRefusalPill("))
        #expect(cue.contains("announceBareHyper(text)"))
        #expect(!cue.contains("soundIfDrawn"))
        #expect(!cue.contains("soundRefusal"))
    }
}
