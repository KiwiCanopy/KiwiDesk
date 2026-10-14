import Carbon.HIToolbox
import Foundation
import Testing

@testable import KiwiDeskCore

/// A registrar that records what is registered right now, by key
/// and Carbon mask, and reports releases like Carbon does.
@MainActor
private final class LiveRegistrar: HotkeyRegistrar,
    HotkeyReleaseReporting
{
    var onRelease: @MainActor (UInt32) -> Void = { _ in }
    var live:
        [UInt32: (
            code: UInt32, mask: UInt32, raw: HotkeyModifiers,
            fire: () -> Void
        )] = [:]
    private var nextID: UInt32 = 1

    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? {
        defer { nextID += 1 }
        live[nextID] = (keyCode, modifiers.carbonMask, modifiers, handler)
        return nextID
    }

    func unregister(id: UInt32) { live[id] = nil }

    func has(_ code: UInt32, mask: UInt32 = 0) -> Bool {
        live.values.contains { $0.code == code && $0.mask == mask }
    }

    /// Fires the plain (no-modifier) registration of `code`.
    func press(_ code: UInt32) {
        live.values.first { $0.code == code && $0.mask == 0 }?.fire()
    }

    func release(_ code: UInt32) {
        for (id, entry) in live where entry.code == code {
            onRelease(id)
        }
    }
}

/// The Hyper layer (#1870): `hyper+…` combos are registered bare,
/// only while the F18 trigger is held, and gone everywhere else.
@MainActor
@Suite("Hyper layer")
struct HyperLayerTests {
    private let f18 = HyperSourceKey.triggerKeyCode
    private let h = UInt32(kVK_ANSI_H)

    private func manager(
        _ registrar: HotkeyRegistrar
    ) throws -> KeybindingManager {
        let keys = KeybindingManager(registrar: registrar)
        keys.onLog = { _ in }
        let hyperH = try #require(KeyCombo.parse("hyper+h"))
        let plainJ = try #require(KeyCombo.parse("ctrl+j"))
        keys.replaceLayers(
            [KeybindingManager.defaultLayer: [hyperH: 1, plainJ: 2]],
            icons: [:],
            preferredLayer: KeybindingManager.defaultLayer
        )
        return keys
    }

    @Test("with Hyper off a hyper combo registers nothing")
    func offRegistersNothing() throws {
        let registrar = LiveRegistrar()
        _ = try manager(registrar)
        #expect(!registrar.has(h))
        #expect(!registrar.has(f18))
        #expect(registrar.has(UInt32(kVK_ANSI_J), mask: UInt32(controlKey)))
    }

    @Test("the layer is live only while the trigger is held")
    func holdRegistersBare() throws {
        let registrar = LiveRegistrar()
        let keys = try manager(registrar)
        keys.hyperEnabled = true
        #expect(registrar.has(f18))
        #expect(!registrar.has(h))
        registrar.press(f18)
        #expect(registrar.has(h))  // bare: no modifier mask
        // The registrar is never handed the hyper bit.
        #expect(!registrar.live.values.contains { $0.raw.contains(.hyper) })
        registrar.release(f18)
        #expect(!registrar.has(h))
        #expect(registrar.has(f18))
    }

    @Test("a held layer dies with every teardown")
    func teardownDropsTheLayer() throws {
        let registrar = LiveRegistrar()
        let keys = try manager(registrar)
        keys.hyperEnabled = true
        registrar.press(f18)
        keys.suspend()
        #expect(!registrar.has(h))
        #expect(!registrar.has(f18))
        keys.resume()
        #expect(registrar.has(f18))
        registrar.press(f18)
        keys.hyperEnabled = false
        #expect(!registrar.has(h))
        #expect(!registrar.has(f18))
    }

    @Test("the trigger answers whichever modifiers are down")
    func triggerCoversEveryMask() throws {
        let registrar = LiveRegistrar()
        let keys = try manager(registrar)
        keys.hyperEnabled = true
        #expect(registrar.has(f18, mask: UInt32(shiftKey)))
        #expect(
            registrar.has(f18, mask: UInt32(cmdKey | controlKey))
        )
        let masks = Set(
            registrar.live.values.filter { $0.code == f18 }.map(\.mask)
        )
        #expect(masks.count == 16)  // every set of ⌃⌥⇧⌘
    }

    @Test("a layer change mid-hold keeps the trigger and the hold")
    func activateMidHoldKeepsTheHold() throws {
        let registrar = LiveRegistrar()
        let keys = try manager(registrar)
        keys.hyperEnabled = true
        registrar.press(f18)
        let hyperK = try #require(KeyCombo.parse("hyper+k"))
        keys.replaceLayers(
            [KeybindingManager.defaultLayer: [hyperK: 3]],
            icons: [:],
            preferredLayer: KeybindingManager.defaultLayer
        )
        let k = UInt32(kVK_ANSI_K)
        #expect(registrar.has(k))  // the new layer, still held
        #expect(!registrar.has(h))
        registrar.release(f18)  // the trigger survived: it arrives
        #expect(!registrar.has(k))
    }

    @Test("the watchdog ends a hold whose release never came")
    func watchdogEndsTheHold() throws {
        let registrar = LiveRegistrar()
        let keys = try manager(registrar)
        var fire: (@MainActor () -> Void)?
        var delay: TimeInterval?
        keys.hyperSchedule = { seconds, work in
            delay = seconds
            fire = work
            return {}
        }
        keys.hyperEnabled = true
        registrar.press(f18)
        #expect(registrar.has(h))
        #expect(delay == HyperLayer.maxHoldSeconds)
        let work = try #require(fire)
        work()
        #expect(!registrar.has(h))
        #expect(registrar.has(f18))
    }

    @Test("other releases still reach the glide")
    func releasesFanOut() throws {
        let registrar = LiveRegistrar()
        let keys = try manager(registrar)
        keys.hyperEnabled = true
        #expect(keys.holdGlide.releaseCapable)
        registrar.press(f18)
        #expect(registrar.has(h))
        registrar.release(h)  // not the trigger: the layer stays
        #expect(registrar.has(h))
    }

    @Test("a registrar without releases arms no trigger")
    func pressOnlyRegistrarArmsNothing() throws {
        let registrar = PressOnlyRegistrar()
        let keys = try manager(registrar)
        keys.hyperEnabled = true
        #expect(registrar.codes.isEmpty == false)  // ctrl+j
        #expect(!registrar.codes.contains(f18))
        let hyperH = try #require(KeyCombo.parse("hyper+h"))
        #expect(keys.activationFailures.contains(hyperH))
    }

    @Test("Carbon never sees the hyper bit")
    func maskIsStripped() {
        let mods: HotkeyModifiers = [.hyper, .shift]
        #expect(mods.carbonMask == UInt32(shiftKey))
    }
}

@MainActor
private final class PressOnlyRegistrar: HotkeyRegistrar {
    var codes: [UInt32] = []
    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? {
        codes.append(keyCode)
        return UInt32(codes.count)
    }
    func unregister(id: UInt32) {}
}
