import AppKit

/// The bars' right-click menus (#1518, the owner's 2026-09-28
/// ruling in its body): what a hit shows above the shelf section,
/// which ends every menu. A row that cannot apply is greyed, never
/// hidden (#802).
extension KiwiCore {
    func wireBarMenus() {
        spaceBars.contextMenus = shelves.contextMenus
        appBars.contextMenus = shelves.contextMenus
        shelves.contextMenus.rows = { [weak self] in
            self?.barMenuRows($0) ?? []
        }
    }

    func barMenuRows(_ hit: BarHit) -> [BarMenuRow] {
        let above: [BarMenuRow]
        switch hit {
        case .space(let id):
            above =
                spaceChipRows(id) + [.separator]
                + spaceLifecycleRows(id)
        case .disc: above = [glyphSpanRow()]
        case .glyph(let windows):
            above = windowRows(windows, movable: true)
        case .appItem(let windows):
            above = windowRows(windows, movable: false)
        case .divider: above = [dividerResetRow()]
        case .count, .empty: above = []
        }
        guard !above.isEmpty else { return shelfSectionRows() }
        return above + [.separator] + shelfSectionRows()
    }

    /// The section every menu ends with, inline and headerless.
    func shelfSectionRows() -> [BarMenuRow] {
        [
            landingRow(
                L("bar.menu.shelf_settings", "KiwiShelf Settings…"),
                .shelf
            ),
            landingRow(L("bar.menu.looks", "Looks…"), .looks),
            landingRow(
                L("bar.menu.advanced_colors", "Advanced Colors…"),
                .advancedColors
            ),
        ]
    }

    private func landingRow(
        _ title: String,
        _ landing: SettingsLanding
    ) -> BarMenuRow {
        .action(title) { [weak self] in
            self?.barMenuHooks.openSettings(landing)
        }
    }

    /// A Space chip: its Layout menu — the status item's rows,
    /// Keep included, since a mode picked here is a temporary
    /// layout like any other (#1179) — and its Settings card.
    private func spaceChipRows(_ id: SpaceID) -> [BarMenuRow] {
        guard let space = state.workspaces[id] else { return [] }
        let shown = state.workspaces.allDisplays.compactMap {
            state.workspaces.activeSpace(on: $0.id)
        }
        let spaces = Array(Set(shown + [id]))
        let saved = savedModes(for: spaces)
        let drifted = { (space: SpaceID) in
            LayoutModeRows.drifted(
                live: self.state.workspaces[space]?.mode,
                saved: saved[space]
            )
        }
        var layout = LayoutModeRows.entries(
            live: space.mode,
            drifted: drifted(id),
            words: LayoutModeRows.coreWords
        ).map { entry in
            BarMenuRow.action(
                entry.title,
                checked: entry.checked,
                symbol: entry.symbol,
                subtitle: entry.subtitle
            ) { [weak self] in
                _ = self?.execute(
                    "set_mode",
                    args: [.string(id.raw), .string(entry.mode.rawValue)]
                )
            }
        }
        if let profile = profiles.currentName {
            layout += [
                .separator,
                .action(
                    L(
                        "menu.layout.keep",
                        "Keep Layout in Profile “%1$@”",
                        profile
                    ),
                    enabled: LayoutModeRows.keepArmed(
                        drifts: spaces.map(drifted) + [spaceSetDrifted()]
                    )
                ) { [weak self] in
                    self?.barMenuHooks.keepLayout()
                },
            ]
        }
        return [
            .submenu(
                L("menu.layout", "Layout"),
                symbol: "rectangle.3.group",
                layout
            ),
            landingRow(
                L("bar.menu.space_settings", "Space Settings…"),
                .space(id)
            ),
        ]
    }

    /// A `+N` disc: how many glyphs a Space shows, written to the
    /// live profile like a Settings change (#1518 build notes).
    private func glyphSpanRow() -> BarMenuRow {
        let current = tiler.settings.spaceBarStyle.resolvedGlyphSpan
        let rows = SpaceBarStyle.glyphSpanRange.map { span in
            BarMenuRow.action("\(span)", checked: span == current) {
                [weak self] in
                self?.setGlyphSpanFromBar(span)
            }
        }
        return .submenu(
            L("space_bar.glyph_span", "Glyphs per Space"),
            rows
        )
    }

    /// The divider's double-click, spelled out: greyed at the
    /// default it would reset to.
    private func dividerResetRow() -> BarMenuRow {
        .action(
            L("bar.menu.reset_minimum", "Reset Space Bar Minimum"),
            enabled: tiler.settings.kiwishelf.minimum
                != KiwiShelf.resetMinimum
        ) { [weak self] in
            self?.dragShelfMinimum(KiwiShelf.resetMinimum, committed: true)
        }
    }

    /// Through the setter Lua and the CLI take, then into the live
    /// profile's file with its clamp, and to an open draft.
    func setGlyphSpanFromBar(_ span: Int) {
        execute("space_bar.set_glyph_span", args: [.number(Double(span))])
        let settled = tiler.settings.spaceBarStyle.glyphSpan
        writeThroughLiveProfile { $0.spaceBarStyle.glyphSpan = settled }
    }
}
