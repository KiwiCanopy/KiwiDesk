import KiwiDeskCore

/// The draft's Screen pins read onto the connected screens (#3647).
/// The draft stores each pin by the number its screen holds, as the
/// profile does; every Settings reader and writer of a pin goes
/// through these and `place`, so no view spells the crossing.
extension SettingsModel {
    /// Which connected screen holds which number — Core's one order.
    var screenOrder: ScreenOrder { core.liveScreenOrder }

    /// Every draft pin as the runtime keys it: a screen fingerprint,
    /// or an area key.
    var resolvedPins: [SpaceID: String] {
        screenOrder.runtime(config.spacePins)
    }

    /// `space`'s pin as the runtime keys it, if it has one on the
    /// connected screens.
    func pin(of space: SpaceID) -> String? {
        config.spacePins[space]
            .flatMap { screenOrder.runtimeKey(of: $0)?.description }
    }
}
