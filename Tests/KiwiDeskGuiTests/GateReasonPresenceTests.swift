import Testing

@testable import KiwiDesk

/// A surfacing gate dims nothing (#815), split from
/// `GateReasonPlacementTests` at the file ceiling.
@Suite("Gate reason presence (#815)")
@MainActor
struct GateReasonPresenceTests {
    private func channel(
        _ key: SettingKey
    ) -> GateReasonPlacement.Channel? {
        GateReasonPlacement.channel(key) { $0.placement }
    }

    /// A surfacing condition dims nothing, so it carries no
    /// channel at all — the distinction that keeps
    /// `causeIsOnSurface` from answering two questions with one
    /// name.
    @Test("a presence condition has no reason to place")
    func surfacingConditionsCarryNoChannel() {
        #expect(SettingRuntimeGate.layersExist.greys == false)
        #expect(SettingRuntimeGate.reduceMotion.greys)
        // The Layers card surfaces on `layersExist`; nothing
        // there is dimmed, so nothing owes a sentence.
        #expect(channel(.shortcuts(.layers)) == nil)
    }
}
