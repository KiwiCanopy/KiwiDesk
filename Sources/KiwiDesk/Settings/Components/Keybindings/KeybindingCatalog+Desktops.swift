import KiwiDeskCore

/// The macOS **Desktop** rows (#884's verbs, GUI half): the
/// Desktop-side twins of the per-Space families, split into
/// their own file so `KeybindingCatalog.swift` stays inside the
/// §2.1 target.
///
/// A Desktop is Mission Control's, a Space is KiwiDesk's own
/// (config-vocabulary.md), so these rows say **Desktop** and
/// carry the same `square.on.square` glyph the Profiles card
/// draws beside a Desktop — one word and one picture for the
/// concept, wherever the app names it.
///
/// **The Lua argument is a bare NUMBER**, not a quoted string:
/// the verbs read it through `intValue`, which answers nil for
/// a string, so `focus_desktop("3")` would refuse at runtime
/// while looking right in the row. `desktopArg` is the one
/// place that form is authored.
extension KeybindingCatalog {
    /// One "Go to Desktop …" row per Desktop (#26).
    static func goToDesktop(_ desktops: [Int]) -> [NavCommand] {
        desktops.map { number in
            NavCommand(
                label: "Go to Desktop \(number)",
                lua: "KiwiDesk.focus_desktop"
                    + "(\(desktopArg(number)))",
                icon: desktopIcon,
                displayLabel: {
                    L(
                        "keybinding.focus_desktop",
                        "Go to Desktop %1$@",
                        String(number)
                    )
                }
            )
        }
    }

    /// The per-Desktop "Move to …" / "… & follow" pairs,
    /// interleaved per Desktop — composed from the two
    /// half-builders below rather than repeating their Lua, for
    /// the reason `moveToSpace` gives: a second copy of either
    /// body is the byte-for-byte drift that silently demotes an
    /// import to Custom (#4).
    static func moveToDesktop(
        _ desktops: [Int]
    ) -> [NavCommand] {
        zip(
            moveToDesktopRows(desktops),
            moveToDesktopFollowRows(desktops)
        )
        .flatMap { [$0, $1] }
    }

    /// One "Move to Desktop …" row per Desktop (#25). No follow:
    /// the window leaves and you stay, which is why the pair is
    /// two rows rather than one row with a modifier.
    static func moveToDesktopRows(
        _ desktops: [Int]
    ) -> [NavCommand] {
        desktops.map { number in
            NavCommand(
                label: "Move to Desktop \(number)",
                lua: "KiwiDesk.move_to_desktop"
                    + "(\(desktopArg(number)))",
                icon: desktopIcon,
                displayLabel: {
                    L(
                        "keybinding.move_to_desktop",
                        "Move to Desktop %1$@",
                        String(number)
                    )
                }
            )
        }
    }

    /// One "Move to Desktop … & follow" row per Desktop.
    static func moveToDesktopFollowRows(
        _ desktops: [Int]
    ) -> [NavCommand] {
        desktops.map { number in
            NavCommand(
                label: "Move to Desktop \(number) & follow",
                lua: "KiwiDesk."
                    + "move_to_desktop_and_follow"
                    + "(\(desktopArg(number)))",
                icon: desktopIcon,
                displayLabel: {
                    L(
                        "keybinding.move_to_desktop_follow",
                        "Move to Desktop %1$@ & follow",
                        String(number)
                    )
                }
            )
        }
    }

    /// The Desktops the families expand over: the ones that
    /// exist, PLUS every Desktop these bindings already name.
    ///
    /// The union is what keeps a bound row visible. A Desktop
    /// number is macOS topology, not user data — unplug a screen
    /// and Desktops 3–5 are simply gone — while the binding that
    /// named one is still Carbon-registered, still blocks the
    /// recorder, and would otherwise have no row for the
    /// duplicate-combo block's "Go to" to reach. That is #92's
    /// argument, and the per-Space families answer it with a
    /// whole Inactive card because a Space is user data that can
    /// be re-created by name. A Desktop cannot, so the cheaper
    /// answer is right here: keep offering the row.
    ///
    /// Deliberately NOT routed through
    /// `OrphanedShortcuts.perSpaceFamilies` — that list means
    /// "the argument is a `SpaceID`" and drives the space-rename
    /// rewriter, which must never see a Desktop number.
    static func offeredDesktops(
        live: [Int],
        bindings: [KeyBinding]
    ) -> [Int] {
        let bound = bindings.compactMap {
            desktopNumber(from: $0.lua)
        }
        return Set(live).union(bound).sorted()
    }

    /// The catalog row a Desktop-targeting Lua body names, or
    /// nil for anything else — the import classifier's arm.
    ///
    /// Matched by **shape**, the way a resize of any step is
    /// (`resizeShape(from:)`), rather than by looking the body
    /// up in a map built from the live Desktop list. The map
    /// route would leave a binding to a Desktop that is not
    /// currently attached classified `.custom`, so it would read
    /// as raw Lua in the panel and in the Advanced drawer until
    /// the screen came back.
    static func desktopCommand(from lua: String) -> NavCommand? {
        guard let number = desktopNumber(from: lua) else {
            return nil
        }
        let candidates =
            goToDesktop([number])
            + moveToDesktopRows([number])
            + moveToDesktopFollowRows([number])
        return candidates.first { $0.lua == lua }
    }

    /// The Desktop a `focus_desktop` / `move_to_desktop`
    /// (`_and_follow`) body targets, or nil when the body is not
    /// one of the three verbs.
    ///
    /// Reads the verb before the argument so a future
    /// `…_desktop` verb taking something other than a number
    /// cannot be mistaken for one of these.
    static func desktopNumber(from lua: String) -> Int? {
        let verbs = [
            "KiwiDesk.focus_desktop(",
            "KiwiDesk.move_to_desktop(",
            "KiwiDesk.move_to_desktop_and_follow(",
        ]
        guard
            let verb = verbs.first(where: { lua.hasPrefix($0) }),
            lua.hasSuffix(")")
        else { return nil }
        let body = lua.dropFirst(verb.count).dropLast()
        return Int(body)
    }

    /// A Desktop number as the Lua argument the verbs parse: a
    /// bare integer literal. See the type docstring.
    static func desktopArg(_ number: Int) -> String {
        String(number)
    }

    /// The glyph a Desktop row carries, the same one
    /// `DesktopsGroup` draws beside a Desktop in Profiles.
    private static let desktopIcon = "square.on.square"
}
