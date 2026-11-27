import Foundation

/// The fit rule's order for the session (#3647 ▸ no-fit ruling): a
/// setup the base order cannot split everywhere is numbered in the
/// first order that fits, chosen where the order is decided — an
/// apply, a screen change — and kept through a `min_window_size` or
/// split edit, so a Space never moves screens under one. A Save
/// stores the base order, never this.
extension KiwiCore {
    /// The fit's order for `profile` on the connected screens; nil
    /// for another profile or setup.
    func fittedScreenOrder(for profile: String?) -> ScreenOrder? {
        guard let fitted = profiles.screenOrders.fitted,
            fitted.profile == profile,
            MonitorSet(monitors: fitted.order.fingerprints)
                .matches(liveFingerprints)
        else { return nil }
        return fitted.order
    }

    /// Chooses the fit for `profile`, about to apply, from its own
    /// splits and floors.
    func refitScreenOrder(for profile: Profile) {
        fit(
            screenOrder(holding: profile.monitorSets),
            shares: profile.settings.displayAreas,
            floors: profile.settings.areaFloors,
            for: profile.name
        )
    }

    /// Chooses the fit for what is live, at a screen change.
    func refitLiveScreenOrder() {
        fit(
            screenOrder(holding: profiles.active?.monitorSets ?? []),
            shares: tiler.settings.displayAreas,
            floors: tiler.settings.areaFloors,
            for: profiles.currentName
        )
    }

    private func fit(
        _ base: ScreenOrder,
        shares: [String: ScreenShares],
        floors: AreaFloors,
        for profile: String?
    ) {
        profiles.screenOrders.fitted = .init(
            profile: profile,
            order: base.fitting(shares, floors: floors)
        )
    }
}
