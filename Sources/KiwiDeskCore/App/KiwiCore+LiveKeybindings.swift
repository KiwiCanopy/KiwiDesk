import Foundation

/// The structured bindings currently installed, for the
/// read-only shortcuts reference panel (#326).
public struct LiveKeybindingSnapshot: Sendable {
    let layers: [KeyLayer]
    let activeLayer: String

    /// The resolved key modes currently installed.
    public var keyLayers: [KeyLayer] { layers }
    /// The runtime-active mode's name.
    public var activeLayerName: String { activeLayer }
}

extension KiwiCore {
    /// Captures the effective, successfully compiled structured
    /// bindings currently installed. nil outside GUI ownership or
    /// without a live VM.
    public func liveKeybindingSnapshot()
        -> LiveKeybindingSnapshot?
    {
        guard isGuiManaged, keys.lua != nil,
            let layers = appliedStructuredLayers
        else { return nil }
        return LiveKeybindingSnapshot(
            layers: layers,
            activeLayer: keys.currentLayer
        )
    }

    /// Suspends every KiwiDesk Carbon hotkey while a Settings
    /// recorder is armed (#213), so pressing an existing shortcut
    /// to test it can't fire its action. Paired with
    /// `resumeHotkeysForRecording()` when capture ends. Suspend/
    /// resume round-trip the exact table, so both are safe no-ops
    /// when nothing is registered; system shortcuts are untouched.
    public func suspendHotkeysForRecording() {
        keys.suspend()
    }

    public func resumeHotkeysForRecording() {
        keys.resume()
    }
}
