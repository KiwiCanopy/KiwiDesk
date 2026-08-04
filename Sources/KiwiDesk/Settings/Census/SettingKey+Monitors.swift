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
            // Ungated on purpose. These were briefly given
            // `.runtime(.monitorsDisconnected)` — the condition
            // that surfaces the banner below — to record why the
            // picture disappears. It records the wrong thing: a
            // census gate reads "shows while true" everywhere
            // else in the enum, so the same tag on the banner and
            // on the rows it REPLACES declares one condition with
            // two opposite meanings, knowable only inside the
            // resolver. The banner's own gate already says the
            // picture is unavailable; these rows need no second,
            // inverted copy of it (#678 turn 13b, architect
            // review).
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
            return .text("monitors.clear_pin.label")
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
