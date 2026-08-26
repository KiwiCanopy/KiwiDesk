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
/// **The Lua argument is a bare NUMBER**, not a quoted string —
/// `spaceArg`'s twin, one type over, and `desktopArg` is the
/// one place that form is authored.
///
/// Not because a quoted one would refuse: `JSONValue.intValue`
/// coerces a numeric string, so `focus_desktop("3")` reaches
/// the verb intact. The cost is IDENTITY. A `NavCommand` is
/// keyed by its Lua body, the import classifier matches that
/// body byte-for-byte (#4), and `docs/lua-reference.md` teaches
/// the bare form — so a quoted catalog would file a
/// hand-written `focus_desktop(3)` as Custom while the row it
/// belongs in sat right there, and `desktopNumber(from:)`, which
/// parses an Int, would stop recognising the catalog's own rows.
extension KeybindingCatalog {
    /// One "Go to Desktop …" row per Desktop (#26).
    static func goToDesktop(
        _ desktops: [Int],
        absent: Set<Int> = []
    ) -> [NavCommand] {
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
                },
                unavailable: awayMark(number, in: absent)
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
        _ desktops: [Int],
        absent: Set<Int> = []
    ) -> [NavCommand] {
        zip(
            moveToDesktopRows(desktops, absent: absent),
            moveToDesktopFollowRows(desktops, absent: absent)
        )
        .flatMap { [$0, $1] }
    }

    /// One "Move to Desktop …" row per Desktop (#25). No follow:
    /// the window leaves and you stay, which is why the pair is
    /// two rows rather than one row with a modifier.
    static func moveToDesktopRows(
        _ desktops: [Int],
        absent: Set<Int> = []
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
                },
                unavailable: awayMark(number, in: absent)
            )
        }
    }

    /// One "Move to Desktop … & follow" row per Desktop.
    static func moveToDesktopFollowRows(
        _ desktops: [Int],
        absent: Set<Int> = []
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
                },
                unavailable: awayMark(number, in: absent)
            )
        }
    }

    /// The short spoken mark for a row whose Desktop is not on
    /// any screen right now, or nil when it is.
    ///
    /// Short on purpose: it is the row's `.accessibilityHint`,
    /// read after the row's own name and combo, and the family's
    /// block sentence carries the explanation. `absent` is
    /// EMPTY for every caller with no machine in its question —
    /// the diff readout, the conflict roster, the import
    /// classifier — which is why it defaults so.
    private static func awayMark(
        _ number: Int,
        in absent: Set<Int>
    ) -> (@MainActor () -> String)? {
        guard absent.contains(number) else { return nil }
        return {
            L(
                "keybinding.desktop_away.axhint",
                "Not connected right now."
            )
        }
    }

    /// Which Desktops each family offers a row for, and which
    /// of those are not attached right now.
    ///
    /// **Per family, not one shared list.** The offer is
    /// `live ∪ bound-to-THIS-family's-verb`, because a binding
    /// keeps its OWN row alive and nothing more: sharing one
    /// list meant binding `move_to_desktop(5)` conjured an
    /// unbound "Go to Desktop 5" row in the Focus card for a
    /// Desktop that does not exist — offering a verb the user
    /// never asked for, on hardware that cannot run it (owner,
    /// on device, 2026-08-26).
    ///
    /// The move PAIR shares one list on purpose. Its two
    /// families render interleaved, and `renderedRows` zips the
    /// columns and truncates to the shorter one — so a Desktop
    /// present in one and not the other would silently drop
    /// rows off the end of both.
    struct DesktopOffer: Equatable {
        /// What `focusDesktop` expands over.
        var focus: [Int] = []
        /// What BOTH move families expand over — see above.
        var move: [Int] = []
        /// Of either list, the ones not on any screen now.
        var absent: Set<Int> = []

        /// The empty offer: no Desktop draws a row.
        static let none = DesktopOffer()
    }

    /// Builds the offer from what exists and what is bound.
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
    /// answer is right here: keep offering the row, dimmed.
    ///
    /// Deliberately NOT routed through
    /// `OrphanedShortcuts.perSpaceFamilies` — that list means
    /// "the argument is a `SpaceID`" and drives the space-rename
    /// rewriter, which must never see a Desktop number.
    ///
    /// An EMPTY `live` is a legitimate call, not the degenerate
    /// one: it means the caller has no machine in its question —
    /// the settings diff narrates two saved configs and has no
    /// business asking what is plugged in — and it reads the
    /// same as "the bridge is absent", which is also correct,
    /// since neither may drop a row the user authored.
    static func desktopOffer(
        live: [Int],
        bindings: [KeyBinding]
    ) -> DesktopOffer {
        var focusBound: Set<Int> = []
        var moveBound: Set<Int> = []
        for binding in bindings {
            guard
                let number = desktopNumber(from: binding.lua)
            else { continue }
            if binding.lua.hasPrefix(focusVerbPrefix) {
                focusBound.insert(number)
            } else {
                moveBound.insert(number)
            }
        }
        let liveSet = Set(live)
        return DesktopOffer(
            focus: liveSet.union(focusBound).sorted(),
            move: liveSet.union(moveBound).sorted(),
            absent: focusBound.union(moveBound)
                .subtracting(liveSet)
        )
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
        guard
            let verb = verbPrefixes.first(where: {
                lua.hasPrefix($0)
            }),
            lua.hasSuffix(")")
        else { return nil }
        let body = lua.dropFirst(verb.count).dropLast()
        // Digits only. `Int` accepts a sign, and both signed
        // forms round-trip through `desktopArg` into a row that
        // cannot work: `(-1)` draws a row for a target the verb
        // refuses (`number >= 1`), and `(+3)` widens the offer
        // with a Desktop whose generated row spells `(3)` — a
        // duplicate that can never carry the binding it came
        // from.
        guard body.allSatisfy(\.isNumber) else { return nil }
        return Int(body)
    }

    /// `KiwiDesk.<verb>(` for each of the three, DERIVED from the
    /// row builders rather than spelled a second time.
    ///
    /// §5 invites renaming a Lua verb outright, and a hand copy
    /// here would survive one: the rows would author the new
    /// spelling while this parse still matched the old, which
    /// demotes every Desktop binding to Custom and un-teaches
    /// the classifier its own catalog. The Space side avoids the
    /// same trap by sharing `SpaceLuaArg`; this is the one-type
    /// version of that.
    private static let verbPrefixes: [String] = {
        let sentinel = 0
        return
            (goToDesktop([sentinel])
            + moveToDesktopRows([sentinel])
            + moveToDesktopFollowRows([sentinel]))
            .map { String($0.lua.prefix { $0 != "(" }) + "(" }
    }()

    /// `KiwiDesk.focus_desktop(` alone — which family a binding
    /// belongs to, derived for the same reason `verbPrefixes` is.
    /// Anything parsing as a Desktop verb and NOT carrying this
    /// prefix is one of the move pair.
    private static let focusVerbPrefix: String = {
        let lua = goToDesktop([0]).first?.lua ?? ""
        return String(lua.prefix { $0 != "(" }) + "("
    }()

    /// A Desktop number as the Lua argument the verbs parse: a
    /// bare integer literal. See the type docstring.
    static func desktopArg(_ number: Int) -> String {
        String(number)
    }

    /// The glyph a Desktop row carries. `DesktopGlyph.symbol`
    /// is the one copy — the type docstring claims these rows
    /// picture a Desktop the way Profiles does, and a second
    /// literal here would be a claim nothing holds.
    private static let desktopIcon = DesktopGlyph.symbol
}
