import Foundation

/// The fit rule's order for the session (#3647 ▸ no-fit ruling): a
/// setup the base order cannot split everywhere is numbered in the
/// first order that fits, chosen where the order is decided — an
/// apply, a screen change — and kept through a `min_window_size` or
/// split edit, so a Space never moves screens under one. A Save
/// stores the base order, never this.
extension KiwiCore {
    /// The fit's order for `profile` on the connected screens, while
    /// `sets` still number them in the base it was chosen from; nil
    /// for another profile, setup or base, so a Save, a pick or the
    /// reset that moves the base ends it.
    func fittedScreenOrder(
        for profile: String?,
        holding sets: [MonitorSet]
    ) -> ScreenOrder? {
        guard let fitted = profiles.screenOrders.fitted,
            fitted.profile == profile,
            fitted.base == screenOrder(holding: sets)
        else { return nil }
        return fitted.order
    }

    /// The fit's order for what is live.
    var liveFittedScreenOrder: ScreenOrder? {
        fittedScreenOrder(
            for: profiles.currentName,
            holding: profiles.active?.monitorSets ?? []
        )
    }

    /// Chooses the fit for `profile`, about to apply, from its own
    /// splits and floors: at an explicit load, or where none stands
    /// for it, so a re-apply — a Save among them — never renumbers.
    func refitScreenOrder(for profile: Profile, cause: ProfileApplyCause) {
        guard
            cause == .explicit
                || fittedScreenOrder(
                    for: profile.name,
                    holding: profile.monitorSets
                ) == nil
        else { return }
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
            base: base,
            order: base.fitting(shares, floors: floors)
        )
    }
}
