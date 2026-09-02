import AppKit

/// The Space Bar's item-building half, split from
/// `KiwiCore+SpaceBar` at the §2.1 ceiling: one item per Space
/// the display holds, each with its app glyphs. Everything is
/// read from snapshotted state — no AX calls here either.
extension KiwiCore {
    /// The display's Spaces in profile order, each with its
    /// identifier and app glyphs. `hide_empty` drops empty
    /// spaces except the current one (it always stays — cold
    /// start must not collapse the strip).
    func spaceBarItems(
        display: DisplayID,
        style: SpaceBarStyle
    ) -> [SpaceBarOverlay.Item] {
        // SHOWN, not focused: which Space this screen is
        // displaying. The presence and focus questions below
        // take the one active Space instead (#1214).
        let current = state.workspaces.currentSpace(on: display)
        return state.workspaces.spaces(on: display)
            .compactMap { id in
                guard let space = state.workspaces[id] else {
                    return nil
                }
                let (apps, overflow, focusHidden) = spaceBarApps(
                    in: space,
                    style: style
                )
                if style.hideEmpty, apps.isEmpty,
                    id != current
                {
                    return nil
                }
                return SpaceBarOverlay.Item(
                    space: id,
                    spaceGlyph: spaceIdentifier(for: id),
                    apps: apps,
                    active: id == current,
                    overflow: overflow,
                    // Only the active space carries the system
                    // focus, and on a second screen `current` is
                    // not it (#1214): an inactive space's
                    // `focused` is just its own last-focused
                    // window, so tinting the `+n` off it marks a
                    // focus no glyph on that bar wears.
                    focusInOverflow: id == activeSpace?.id
                        && focusHidden
                )
            }
    }

    /// Adjacent same-app runs in the space's flat array order
    /// collapse into one glyph + count (the App Bar's grouping
    /// model, without focused-inside expansion), then the cap
    /// keeps the first `style.resolvedGlyphCap` slots (#376).
    /// Grouping runs first by design so the cap counts app
    /// *groups*, not raw windows. Returns the visible slots and
    /// the number of *windows* hidden past the cap (the "+n"
    /// badge).
    func spaceBarApps(
        in space: Space,
        style: SpaceBarStyle
    ) -> (
        apps: [SpaceBarItemView.App],
        overflow: Int,
        focusHidden: Bool
    ) {
        // One pass: ids and names stay index-aligned with no
        // unreachable "?" fallback. Sticky glyphs TRAVEL with
        // the user (#414 QA): a sticky window is listed only
        // under the item of the space it RENDERS on — appended
        // there when homed elsewhere, pruned from every other
        // item (its home's included) — so one glyph always sits
        // where the user is, instead of cloning onto every item
        // at once.
        //
        // That render verdict is asked with the ONE active
        // space, the same value the layout and the App Bar pass
        // (#1214): handing each display's own shown space in as
        // if it were the focused one told EVERY screen's bar
        // that a ∞ window rendered there.
        let members = state.effectiveMembers(of: space)
        // Transient overlays (a popup's AX windows, a launcher
        // panel) are dropped HERE, before grouping and the cap,
        // so no slot is reserved for a glyph nobody draws — the
        // same draw-time decision the focus ring already makes
        // (#300, #683), never a widening of tracking or of the
        // ignore gate.
        let pairs = members.compactMap { id -> (WindowID, String, Bool)? in
            guard let window = state.windows[id],
                !window.isTransientOverlay
            else { return nil }
            let isSpecial = window.isFloating || window.isSticky
            return (id, window.appName, isSpecial)
        }
        let windows = pairs.map { $0.0 }
        let groups = Self.adjacentRuns(
            of: pairs.map { $0.1 },
            specials: pairs.map { $0.2 }
        ).map { Array(windows[$0]) }
        let cap = style.resolvedGlyphCap
        let visible = groups.prefix(cap)
        let hidden = groups.dropFirst(cap)
        let apps = visible.compactMap { group in
            spaceBarApp(group: group, space: space, style: style)
        }
        // The focused window can be hidden past the cap: the "+n"
        // then tints to signal focus is behind it (#376). It
        // reads the SYSTEM focus, like every glyph beside it —
        // an injected ∞ traveler holds `lastFocused` and can
        // never be the membership-guarded `space.focused`
        // (#431), so asking the slot left the one case this
        // tint exists for showing nothing at all.
        let focusHidden =
            state.workspaces.lastFocused.map { focus in
                hidden.contains { $0.contains(focus) }
            } ?? false
        return (apps, hidden.reduce(0) { $0 + $1.count }, focusHidden)
    }

    /// One glyph slot for a same-app run. Internal rather
    /// than `private` because the front-app segment builds
    /// its single-window slot with it, across the file
    /// split — the bar has two parts, and the segment sits
    /// with the driver that assembles them.
    func spaceBarApp(
        group: [WindowID],
        space: Space,
        style: SpaceBarStyle
    ) -> SpaceBarItemView.App? {
        guard let first = group.first,
            let window = state.windows[first]
        else { return nil }
        let name = window.appName
        let icon = NSRunningApplication(
            processIdentifier: window.pid
        )?.icon
        var glyph = appFont.glyph(
            forAppName: name,
            source: style.iconSource
        )
        if glyph == nil, icon == nil {
            // No image either way: fall back to the App Font
            // (specific glyph, else `Default`) so the slot
            // never renders blank — monochrome, so it adapts
            // to the bar's colors.
            glyph =
                appFont.glyph(
                    forAppName: name,
                    source: .appFont
                )
                ?? appFont.glyph(
                    forAppName: "Default",
                    source: .appFont
                )
        }
        return SpaceBarItemView.App(
            name: name,
            icon: icon,
            glyph: glyph,
            // The SYSTEM focus, not this space's own memory:
            // a foreign sticky window can hold it (#414 QA —
            // its glyph was stuck on the unfocused dim tier).
            focused: state.workspaces.lastFocused
                .map(group.contains) ?? false,
            count: group.count,
            // Badge inheritance (#414): a group aggregates its
            // children's states — an "at least one" signal.
            sticky: group.contains {
                state.windows[$0]?.isSticky == true
            },
            floating: group.contains {
                state.windows[$0]?.isFloating == true
            },
            // The run's first sticky member picks the badge glyph
            // (#445): global → infinity, display → pin.fill.
            stickyScope: group.compactMap {
                state.windows[$0]
            }.first(where: \.isSticky)?.stickyScope ?? .none
        )
    }

    /// The configured Space icon (SF Symbol | emoji | single
    /// character), or the settled fallbacks: numeric id →
    /// plain tinted digits, named space → 2-character
    /// uppercase monogram.
    func spaceIdentifier(
        for id: SpaceID
    ) -> SpaceBarItemView.Identifier {
        if let icon = tiler.settings.spaceIcons[id],
            !icon.isEmpty
        {
            if NSImage(
                systemSymbolName: icon,
                accessibilityDescription: nil
            ) != nil {
                return .symbol(icon)
            }
            // Emoji render untinted (they take no template
            // tint); plain characters follow the state color.
            // U+FE0F covers text-default scalars forced into
            // emoji presentation ("❤️", "☀️").
            let emoji = icon.unicodeScalars.contains {
                $0.properties.isEmojiPresentation
                    || $0.value == 0xFE0F
            }
            return .text(icon, tinted: !emoji)
        }
        // Numeric ids render as plain digits (QA 2026-07-19):
        // the old `N.square` symbol is self-bordered, and with
        // the default boxed background wrapping the item it
        // read as a box-in-a-box. Plain text also drops the
        // symbol's 0–50 range limit. Digits skip the monogram's
        // uppercase-prefix (they are already their own short
        // string).
        if Int(id.raw) != nil {
            // Three digits still fit the square cell; longer
            // ids truncate like the monogram rather than clip
            // under the item's masksToBounds.
            return .text(
                String(id.raw.prefix(3)),
                tinted: true
            )
        }
        return .text(
            String(id.raw.prefix(2)).uppercased(),
            tinted: true
        )
    }
}
