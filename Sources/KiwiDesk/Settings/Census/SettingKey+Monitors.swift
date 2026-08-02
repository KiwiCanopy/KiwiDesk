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
            return .row(.monitors, .spacePlacement, .atRest)
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
