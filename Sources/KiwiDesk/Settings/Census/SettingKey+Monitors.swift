/// Monitors: space placement pins and fingerprints.

enum MonitorsKey: String, CaseIterable, Hashable {
    case spacePins = "config.spacePins[space]"
    case mainSpaces = "config.mainSpaces"
    case orphanPinClear = "(action) monitors.orphan_pin.clear"
    case fingerprints = "(readonly) monitors.fingerprints"
    case placementUnavailable = "(state) monitors.placementUnavailable"
}

extension MonitorsKey {
    var placement: SettingPlacement {
        switch self {
        case .spacePins, .mainSpaces:
            // The picture's two row families are WITHHELD by the
            // same condition that surfaces the banner below: with
            // the profile's monitors away there are no frames to
            // draw cards from, and the banner stands in for them.
            // Recording the gate here is what keeps that pairing
            // knowable from the census rather than only from the
            // view's if/else (#678 turn 13b).
            return .row(
                .monitors,
                .spacePlacement,
                .atRest,
                gate: .runtime(.monitorsDisconnected)
            )
        case .orphanPinClear:
            return .row(
                .monitors,
                .pinnedToDisconnectedMonitors,
                .atRest,
                gate: .runtime(.orphanPinsExist)
            )
        case .fingerprints:
            return .row(.monitors, .monitorFingerprints, .showMore)
        case .placementUnavailable:
            return .row(
                .monitors,
                .spacePlacement,
                .atRest,
                gate: .runtime(.monitorsDisconnected)
            )
        }
    }
}

extension MonitorsKey {
    var text: SettingRowText {
        switch self {
        case .spacePins:
            return .dynamic
        case .mainSpaces:
            return .text("monitor_card.follows_main")
        case .orphanPinClear:
            return .text("monitors.orphan_pin.help")
        case .fingerprints:
            return .text(
                "monitors.advanced.title",
                caption: "monitors.advanced.caption"
            )
        case .placementUnavailable:
            return .text(
                "monitors.not_connected",
                caption: "monitors.not_connected.caption"
            )
        }
    }
}
