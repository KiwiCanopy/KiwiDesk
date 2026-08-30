import KiwiDeskCore

/// macOS Desktop keybinding catalog rows (#884).
///
/// Uses bare integer arguments for Lua bindings (`desktopArg`, #4).
extension KeybindingCatalog {
    /// "Go to Desktop …" command rows (#26).
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

    /// Interleaved "Move to Desktop" and "Move & follow" rows (#4, #25).
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

    /// "Move to Desktop …" command rows (#25).
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

    /// "Move to Desktop … & follow" command rows.
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

    /// Accessibility hint for disconnected desktop row.
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

    /// Desktops offered in keybinding UI and disconnected status (#92).
    struct DesktopOffer: Equatable {
        var desktops: [Int] = []
        var absent: Set<Int> = []

        static let none = DesktopOffer()
    }

    /// Builds desktop offer from live topology and bound shortcuts (#92).
    static func desktopOffer(
        live: [Int],
        bindings: [KeyBinding]
    ) -> DesktopOffer {
        let bound = Set(
            bindings.compactMap { desktopNumber(from: $0.lua) }
        )
        let liveSet = Set(live)
        return DesktopOffer(
            desktops: liveSet.union(bound).sorted(),
            absent: bound.subtracting(liveSet)
        )
    }

    /// Resolves desktop command matching Lua body.
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

    /// Parses desktop number from Lua command body.
    static func desktopNumber(from lua: String) -> Int? {
        guard
            let verb = verbPrefixes.first(where: {
                lua.hasPrefix($0)
            }),
            lua.hasSuffix(")")
        else { return nil }
        let body = lua.dropFirst(verb.count).dropLast()
        guard body.allSatisfy(\.isNumber) else { return nil }
        return Int(body)
    }

    /// Derived verb prefixes for desktop Lua commands.
    private static let verbPrefixes: [String] = {
        let sentinel = 0
        return
            (goToDesktop([sentinel])
            + moveToDesktopRows([sentinel])
            + moveToDesktopFollowRows([sentinel]))
            .map { String($0.lua.prefix { $0 != "(" }) + "(" }
    }()

    /// Formats desktop number argument for Lua commands.
    static func desktopArg(_ number: Int) -> String {
        String(number)
    }

    /// `DesktopGlyph.symbol` is the one copy of the Desktop-row
    /// glyph — a second literal here would claim these rows
    /// picture a Desktop while nothing holds it.
    private static let desktopIcon = DesktopGlyph.symbol
}
