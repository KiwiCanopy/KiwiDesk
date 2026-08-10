import KiwiDeskCore

/// The Layout override expansion machinery (`+Layout3` is the
/// per-key dispatch): the touched-space filter, the generic
/// field expander, and the two scrolling rows whose words are
/// axis-relative and so need the space's resolved orientation.
extension SettingsValueReadout {
    /// The spaces whose value for one override FIELD differs —
    /// an entry whose other fields changed books no row here, so
    /// each override key narrates only its own edits. Sorted by
    /// name for a stable row order.
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

    /// One row per touched space: "Master ratio · Work", the
    /// missing side reading as unset. `base` overrides the
    /// census label for the two Lua-only keys whose census text
    /// is `.none`.
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

    // MARK: - Scrolling's axis-relative override rows

    /// The anchor's words are axis-relative (Top/Left), so each
    /// side reads its own resolved orientation for the space.
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

    /// Slot-size overrides: the value AND the base label are
    /// axis-relative, so the label follows the DRAFT's resolved
    /// orientation for the space and each side's value reads in
    /// that side's own unit.
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
