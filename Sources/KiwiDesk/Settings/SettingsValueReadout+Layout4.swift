import KiwiDeskCore

/// Layout override readout expansion helpers for SettingsValueReadout.
extension SettingsValueReadout {
    /// Returns sorted spaces where the specific override field changed.
    static func layoutTouched<O, V: Equatable>(
        _ old: [SpaceID: O],
        _ new: [SpaceID: O],
        _ field: (O) -> V?
    ) -> [SpaceID] {
        Set(old.keys).union(new.keys)
            .filter {
                old[$0].flatMap(field) != new[$0].flatMap(field)
            }
            .sorted { $0.raw < $1.raw }
    }

    /// Builds one diff row per touched space; `base` overrides the
    /// census label for the Lua-only keys whose census text is
    /// `.none`.
    static func layoutOvr<O, V: Equatable>(
        _ census: SettingKey,
        _ old: [SpaceID: O],
        _ new: [SpaceID: O],
        base: String? = nil,
        _ field: (O) -> V?,
        _ text: @MainActor (V) -> String
    ) -> [SettingsDiffRow] {
        let baseLabel = base ?? label(for: census)
        return layoutTouched(old, new, field).map { space in
            SettingsDiffRow.change(
                census,
                instance: space.raw,
                label: instanceLabel(baseLabel, space.raw),
                old: old[space].flatMap(field).map(text)
                    ?? unset,
                new: new[space].flatMap(field).map(text)
                    ?? unset
            )
        }
    }

    /// Axis-relative anchor override diff rows for scrolling layout.
    static func layoutAnchorOvrRows(
        _ census: SettingKey,
        old: TilingSettings,
        new: TilingSettings
    ) -> [SettingsDiffRow] {
        let touched = layoutTouched(
            old.scrolling.override,
            new.scrolling.override
        ) { $0.anchor }
        return touched.map { space in
            SettingsDiffRow.change(
                census,
                instance: space.raw,
                label: instanceLabel(
                    label(for: census),
                    space.raw
                ),
                old: layoutAnchorValue(old, space) ?? unset,
                new: layoutAnchorValue(new, space) ?? unset
            )
        }
    }

    private static func layoutAnchorValue(
        _ settings: TilingSettings,
        _ space: SpaceID
    ) -> String? {
        let anchor = settings.scrolling.override[space]?.anchor
        return anchor.map {
            layoutAnchorText(
                $0,
                vertical: layoutSpaceVertical(settings, space)
            )
        }
    }

    /// Axis-relative slot size override diff rows for scrolling layout.
    static func layoutSlotOvrRows(
        _ census: SettingKey,
        old: TilingSettings,
        new: TilingSettings
    ) -> [SettingsDiffRow] {
        let touched = layoutTouched(
            old.scrolling.override,
            new.scrolling.override
        ) { $0.slotSize }
        return touched.map { space in
            SettingsDiffRow.change(
                census,
                instance: space.raw,
                label: instanceLabel(
                    layoutSlotLabel(
                        vertical: layoutSpaceVertical(
                            new,
                            space
                        )
                    ),
                    space.raw
                ),
                old: layoutSlotOvrValue(old, space) ?? unset,
                new: layoutSlotOvrValue(new, space) ?? unset
            )
        }
    }

    private static func layoutSlotOvrValue(
        _ settings: TilingSettings,
        _ space: SpaceID
    ) -> String? {
        let size = settings.scrolling.override[space]?.slotSize
        return size.map {
            layoutSlotValue(
                $0,
                vertical: layoutSpaceVertical(settings, space)
            )
        }
    }
}
