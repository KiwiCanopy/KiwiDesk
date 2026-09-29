import AppKit

/// The Space Bar's item parts, split from `KiwiCore+SpaceBar` at
/// the §2.1 ceiling: a Space's app glyphs, its identifier and the
/// layer item. The run that uses them — each item collapsed to
/// `inactive_content` — is `KiwiCore+SpaceBarRun`. Everything is
/// read from snapshotted state — no AX calls here either.
extension KiwiCore {
    /// A Space chip's content (#1528): the drawn glyphs, the
    /// `+N` discs before and after them, and what it drew.
    struct SpaceBarStripContent {
        var apps: [SpaceBarItemView.App]
        var before: SpaceBarStrip.Disc
        var after: SpaceBarStrip.Disc
        var drawn: SpaceBarStrip.Drawn
    }

    /// While `group_adjacent_windows` is on, adjacent same-app
    /// runs in the space's flat array order collapse into one
    /// glyph + count (the App Bar's grouping model, without
    /// focused-inside expansion), so the span counts app
    /// *groups*; off, every window is its own glyph (#376,
    /// #1725). The drawn
    /// groups are `SpaceBarStrip.window`, centred on the anchor
    /// group — or `held`, what a chip under the pointer drew,
    /// kept while the row still draws it (#1528 items 17, 21).
    func spaceBarApps(
        in space: Space,
        style: SpaceBarLook,
        held: SpaceBarStrip.Drawn? = nil
    ) -> SpaceBarStripContent {
        // One pass: ids and names stay index-aligned with no
        // unreachable "?" fallback. Sticky glyphs TRAVEL with
        // the user (#414 QA): a sticky window is listed only
        // under the item of the space it RENDERS on — appended
        // there when homed elsewhere, pruned from every other
        // item (its home's included) — so one glyph always sits
        // where the user is, instead of cloning onto every item
        // at once.
        // The bar draws the Desktop in front of the user: a
        // window KiwiDesk parked is ours to show, one sitting on
        // another macOS Desktop is macOS's (#1228).
        let members = state.effectiveMembers(of: space)
        // Transient overlays (a popup's AX windows, a launcher
        // panel) are dropped HERE, before grouping and the span,
        // so no slot is reserved for a glyph nobody draws — the
        // same draw-time decision the focus ring already makes
        // (#300, #683), never a widening of tracking or of the
        // ignore gate.
        let pairs = members.compactMap { id -> (WindowID, String, Bool)? in
            guard let member = state.windows[id],
                !member.isTransientOverlay
            else { return nil }
            let isSpecial = member.isFloating || member.isSticky
            return (id, member.appName, isSpecial)
        }
        let windows = pairs.map { $0.0 }
        let groups =
            style.groupAdjacentWindows
            ? Self.adjacentRuns(
                of: pairs.map { $0.1 },
                specials: pairs.map { $0.2 }
            ).map { Array(windows[$0]) }
            : windows.map { [$0] }
        let span = style.resolvedGlyphSpan
        let anchor = stripAnchors(of: space).lazy.compactMap { focus in
            groups.firstIndex { $0.contains(focus) }
        }.first
        let drawn =
            held.flatMap {
                $0.holds(count: groups.count, span: span) ? $0 : nil
            }
            ?? SpaceBarStrip.Drawn(
                window: SpaceBarStrip.window(
                    count: groups.count,
                    span: span,
                    anchor: anchor
                ),
                count: groups.count
            )
        let window = drawn.window
        let apps = groups[window].compactMap { group in
            spaceBarApp(group: group, space: space, style: style)
        }
        // A side hiding the focused window tints its disc (#376).
        // It reads the SYSTEM focus, like every glyph beside it —
        // an injected ∞ traveler holds `lastFocused` and can
        // never be the membership-guarded `space.focused`
        // (#431) — and only on the active Space, the one that
        // carries it: on a second screen the shown Space is not
        // it (#1214), so a tint there marks a focus no glyph on
        // that bar wears.
        let focus =
            space.id == activeSpace?.id ? state.workspaces.lastFocused : nil
        let disc = { (windows: [WindowID]) in
            SpaceBarStrip.Disc(
                windows: windows,
                holdsFocus: focus.map(windows.contains) ?? false
            )
        }
        return SpaceBarStripContent(
            apps: apps,
            before: disc(groups[..<window.lowerBound].flatMap { $0 }),
            after: disc(groups[window.upperBound...].flatMap { $0 }),
            drawn: drawn
        )
    }

    /// The windows a chip may centre on, best first (#1528 item
    /// 17) — WHICH app the strip shows, not which holds the
    /// system focus: the active Space's system focus, the one an
    /// ∞ traveler holds too (#431), then — where that is no
    /// drawn group, a transient overlay's say — the Space's
    /// remembered focus, which is all any other Space has.
    private func stripAnchors(of space: Space) -> [WindowID] {
        let remembered = [space.focused].compactMap { $0 }
        guard space.id == activeSpace?.id,
            let focus = state.workspaces.lastFocused
        else { return remembered }
        return [focus] + remembered
    }

    /// One glyph slot for a same-app run. Internal rather
    /// than `private` because the front-app segment builds
    /// its single-window slot with it, across the file
    /// split — the bar has two parts, and the segment sits
    /// with the driver that assembles them.
    func spaceBarApp(
        group: [WindowID],
        space: Space,
        style: SpaceBarLook
    ) -> SpaceBarItemView.App? {
        guard let first = group.first,
            let member = state.windows[first]
        else { return nil }
        let name = member.appName
        let icon = NSRunningApplication(
            processIdentifier: member.pid
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
        let members = group.compactMap { state.windows[$0] }
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
            sticky: members.contains(where: \.isSticky),
            floating: members.contains(where: \.isFloating),
            // The run's first sticky member picks the badge glyph
            // (#445): global → infinity, display → pin.fill.
            stickyScope: members.first(where: \.isSticky)?
                .stickyScope ?? .none,
            windows: group
        )
    }

    /// The configured Space icon (SF Symbol | emoji | single
    /// character), or the settled fallbacks: numeric id →
    /// plain tinted digits, named space → 2-character
    /// uppercase monogram.
    func spaceIdentifier(
        for id: SpaceID
    ) -> SpaceGlyph {
        Self.spaceIdentifier(
            id: id,
            icon: tiler.settings.spaceIcons[id]
                ?? state.heldSpaces[id]?.icon
        )
    }

    /// The identifier ladder, pure — the bar and the Bars preview
    /// both take it, so the preview cannot read an icon its own
    /// way (#1538, #702).
    public static func spaceIdentifier(
        id: SpaceID,
        icon: String?
    ) -> SpaceGlyph {
        if let icon, !icon.isEmpty {
            return iconGlyph(icon)
        }
        // Numeric ids render as plain digits (QA 2026-07-19):
        // the `N.square` symbol read as a box-in-a-box under the
        // boxed background and stops at 50. Three digits fit the
        // square cell; longer ids truncate like the monogram.
        if Int(id.raw) != nil {
            return textGlyph(String(id.raw.prefix(3)))
        }
        return monogram(id.raw)
    }

    /// The two-character uppercase cut a named Space and an
    /// icon-less layer share (#1169).
    static func monogram(
        _ name: String
    ) -> SpaceGlyph {
        textGlyph(String(name.prefix(2)).uppercased())
    }

    /// Text as a bar glyph: tinted unless it is an emoji, which
    /// takes no template tint — where the bit is set for every
    /// glyph Core builds.
    static func textGlyph(_ text: String) -> SpaceGlyph {
        .text(text, tinted: !isEmoji(text))
    }

    /// Whether a configured icon names an SF Symbol. The one
    /// nil-compared symbol lookup in either tree —
    /// `SymbolClassifierSeamTests` holds that — so no surface can
    /// draw a symbol's NAME as text (#1538, #702).
    public static func iconIsSymbol(_ icon: String) -> Bool {
        NSImage(
            systemSymbolName: icon,
            accessibilityDescription: nil
        ) != nil
    }

    /// A configured icon as a bar glyph — a Space's or a layer's
    /// (`define_layer`'s third argument), one ladder for both.
    static func iconGlyph(
        _ icon: String
    ) -> SpaceGlyph {
        if iconIsSymbol(icon) {
            return .symbol(icon)
        }
        return textGlyph(icon)
    }

    /// U+FE0F covers text-default scalars forced into emoji
    /// presentation ("❤️", "☀️").
    nonisolated static func isEmoji(_ icon: String) -> Bool {
        icon.unicodeScalars.contains {
            $0.properties.isEmojiPresentation
                || $0.value == 0xFE0F
        }
    }

    /// A Space's glyph where there is room for a name: its icon,
    /// else the FULL id — the sticky pill and the menu bar item
    /// (#1413) share it, unlike the bar's monogram above.
    func spaceGlyph(for id: SpaceID) -> SpaceGlyph {
        if let icon = tiler.settings.spaceIcons[id], !icon.isEmpty {
            return Self.iconGlyph(icon)
        }
        return Self.textGlyph(id.raw)
    }

    /// The active shortcut layer's glyph — nil on `default`,
    /// which has no icon and is the bar's resting shape — the
    /// one reading the bar item and the menu bar item share.
    func activeLayerGlyph() -> (
        name: String, glyph: SpaceGlyph,
        hasIcon: Bool
    )? {
        let layer = keys.currentLayer
        guard layer != KeybindingManager.defaultLayer else {
            return nil
        }
        let icon = keys.icon(for: layer) ?? ""
        return (
            layer,
            icon.isEmpty ? Self.monogram(layer) : Self.iconGlyph(icon),
            !icon.isEmpty
        )
    }

    /// The active shortcut layer's item, ahead of the Spaces
    /// (#1169). Read at build time; the rebuild on a switch is
    /// the `layer_change` sink in `KiwiCore+SpaceBar`.
    func spaceBarLayerItem() -> SpaceBarOverlay.Item? {
        activeLayerGlyph().map {
            SpaceBarOverlay.Item(layer: $0.name, glyph: $0.glyph)
        }
    }
}
