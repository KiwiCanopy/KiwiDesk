import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The Windows footer collapses its modifier hints to keycaps
/// before it sheds any (#3249 ▸ Ruling 3): the set is picked once
/// per language on its widest held state, and the hint the held
/// chord lights is always worded.
@Suite("KiwiHub footer keycaps (#3249)")
@MainActor
struct JumpFooterKeycapTests {
    private static func locales() throws -> [String] {
        let directory = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Resources/Locales"
            )
        return try FileManager.default.contentsOfDirectory(
            atPath: directory.path
        )
        .filter { $0.hasSuffix(".json") }
        .map { String($0.dropLast(5)) }
        .sorted()
    }

    private func width(_ view: some View) -> CGFloat {
        NSHostingController(
            rootView: view.font(.caption)
                .fixedSize(horizontal: true, vertical: true)
        )
        .sizeThatFits(in: CGSize(width: 4000, height: 400)).width
    }

    /// The Windows footer's room: the panel less the row's inset,
    /// with no controls beside it.
    private var room: CGFloat {
        typealias Row = JumpFooterRow<EmptyView, EmptyView>
        return JumpPanelView.width - 2 * Row.inset
    }

    /// Which modifier hints each language draws as keycaps, at its
    /// widest: the strip stepping and the last-app opener bound
    /// (#3249 ▸ Ruling 6). A catalog edit that moves a language
    /// into or out of keycaps reds here, and is a ruling.
    @Test("each language's keycaps are pinned")
    func windowsKeycapsArePinned() throws {
        defer { LocalizationManager.shared.select("en") }
        // How many `collapseOrder` slots each draws as keycaps; nil
        // where even all three leave a held state too wide, so the
        // line sheds from the end.
        let pinned: [String: Int?] = [
            "de": 2, "en": 0, "es": 0, "fr": 0, "it": 0, "ja": 0,
            "ko": 0, "pt-BR": 0, "ru": nil, "zh-Hans": 0,
            "zh-Hant": 0,
        ]
        let codes = try Self.locales()
        #expect(Set(codes) == Set(pinned.keys), "a catalog is unpinned")
        let levels = 0...JumpFooter.collapseOrder.count
        for code in codes {
            LocalizationManager.shared.select(code)
            let footer = JumpFooter(
                scope: .windows,
                stripSteps: true,
                lastAppChord: "⌥⇥"
            )
            let level = levels.first { level in
                JumpFooter.heldStates.allSatisfy {
                    width(footer.windowsRow(held: $0, level: level))
                        <= room
                }
            }
            print("footer keycaps \(code): \(level.map(String.init) ?? "-")")
            #expect(level == pinned[code] ?? nil, "\(code)")
        }
    }

    /// The hint a held chord lights is the one it keeps worded, so
    /// the lit hint is never a bare key.
    @Test("the lit hint is the worded one under every chord")
    func litIsWorded() {
        LocalizationManager.shared.select("en")
        // The hint each chord lights, stated apart from the code:
        // ⌘ the digits, else ⌥ Swap here, else ⇧ Move here.
        let expected: [(NSEvent.ModifierFlags, Int)] = [
            (.shift, 1), (.option, 2), ([.shift, .option], 2),
            (.command, 3), ([.shift, .command], 3),
            ([.option, .command], 3), ([.shift, .option, .command], 3),
        ]
        for (held, lit) in expected {
            let footer = JumpFooter(scope: .windows, modifiers: held)
            #expect(footer.leading == lit, "\(held)")
            let full = footer.windowsSlots(held: held)[lit].text
            for level in 0...JumpFooter.collapseOrder.count {
                let drawn = footer.windowsDrawn(held: held, level: level)
                #expect(drawn[lit] == full, "\(held) at \(level)")
            }
        }
        let rest = JumpFooter(scope: .windows).windowsSlots(held: [])
        #expect(rest.allSatisfy { !$0.held })
        #expect(rest[0].keycap == nil)
    }

    /// The Windows line picks its keycaps on its widest held state,
    /// then sheds; a source scan, since a `ViewThatFits` candidate
    /// leaves no trace a headless test can read.
    @Test("the Windows line collapses on its widest state, then sheds")
    func windowsShapeIsWired() throws {
        func read(_ name: String) throws -> String {
            try SourceScan.strippedSource(
                at: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent("Sources/KiwiDesk/Jump")
                    .appendingPathComponent(name)
            )
            .split(whereSeparator: \.isWhitespace).joined()
        }
        let text = try read("JumpFooter+Windows.swift")
        for needle in [
            "ViewThatFits(in:.horizontal){ForEach(0...levels,id:\\.self)"
                + "{windowsStable($0)}",
            "windowsRow(held:modifiers,level:levels,shown:$0,lit:leading)}"
                + "row([],fixed:false)",
            "ForEach(Self.heldStates,id:\\.rawValue){"
                + "windowsRow(held:$0,level:level).hidden()}",
            "windowsRow(held:modifiers,level:level,lit:leading)",
            "collapsed.contains(index)&&!slot.held",
            "reduceMotion?nil:.easeOut(", "value:drawn",
        ] {
            #expect(text.occurrences(of: needle) == 1, "\(needle)")
        }
        let chrome = try read("JumpPanelChrome.swift")
        #expect(chrome.contains("}elseifscope==.windows{windowsFitted"))
    }
}
