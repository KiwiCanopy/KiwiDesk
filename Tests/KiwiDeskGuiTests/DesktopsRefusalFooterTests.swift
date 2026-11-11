import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Desktops side shows its refusals (#3170): the footer's hints
/// give way to ⛔ and the reason until the next key, click or
/// selection change, the refused thing swells, and ⌘↩ Pick up stays
/// unlit on a window that cannot be picked up. A plain drop keeps
/// KiwiHub open on the target line (#3165).
@MainActor
@Suite("Desktops side refusals in the footer")
struct DesktopsRefusalFooterTests {
    private func model(
        _ overview: DesktopOverview = DesktopsStateTests.overview()
    ) -> JumpModel {
        let model = JumpModel(
            snapshot: JumpSnapshot(entries: [], here: nil, hereIcon: nil),
            icons: [:],
            rowCap: 6
        )
        model.loadDesktops = { overview }
        model.setScope(.desktops)
        return model
    }

    private static func blocked() -> DesktopOverview {
        let movie = DesktopsStateTests.window(
            30,
            "Movie",
            block: .fullScreen
        )
        let screen = DesktopOverview.Screen(
            display: DisplayID(1),
            name: "Built-in",
            isMain: true,
            isHere: true,
            desktops: [
                DesktopsStateTests.desktop(
                    1,
                    shown: true,
                    [DesktopsStateTests.line("1", [movie], shown: true)]
                )
            ]
        )
        return DesktopOverview(screens: [screen], yours: nil)
    }

    @Test("a refusal shows until the next key, and swells its line")
    func refusalLastsUntilTheNextKey() {
        LocalizationManager.shared.select("en")
        let model = model()
        var spoken: [String] = []
        model.onRefuse = { spoken.append($0) }
        model.handle(.step(1), repeated: false)
        model.handle(.openSpace, repeated: false)
        #expect(model.desktopsRefusal == "This Space has no windows")
        #expect(spoken == ["This Space has no windows"])
        let place = DesktopsPlace(screen: 1, desktop: 0, line: 1)
        #expect(model.desktopsSwell == .place(place))
        model.handle(.step(-1), repeated: false)
        #expect(model.desktopsRefusal == nil)
    }

    @Test("a click ends a refusal too")
    func clickEndsTheRefusal() {
        let model = model()
        model.handle(.step(1), repeated: false)
        model.handle(.openSpace, repeated: false)
        #expect(model.desktopsRefusal != nil)
        model.clickPlace(
            DesktopsPlace(screen: 1, desktop: 0, line: 0),
            count: 1,
            modifiers: [],
            opens: false
        )
        #expect(model.desktopsRefusal == nil)
    }

    @Test("a carry block swells the window's icon")
    func carryBlockSwellsTheIcon() {
        let model = model(Self.blocked())
        model.handle(.openSpace, repeated: false)
        model.handle(.pickUp, repeated: false)
        #expect(model.desktopsSwell == .window(WindowID(30)))
        #expect(model.desktopsRefusal != nil)
    }

    @Test("the footer state carries the refusal it draws")
    func footerCarriesTheRefusal() throws {
        let model = model()
        model.handle(.step(1), repeated: false)
        model.handle(.openSpace, repeated: false)
        let state = try #require(model.desktops)
        let footer = DesktopsFooterState(
            state,
            refusal: model.desktopsRefusal
        )
        #expect(footer.refusal == model.desktopsRefusal)
        let source = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Jump/JumpPanelView+Footer.swift"
                )
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(source.contains("refusal:model.desktopsRefusal"))
        let chrome = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Jump/JumpPanelChrome.swift"
                )
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(
            chrome.contains(
                "ifletrefusal=desktops?.refusal{desktopsRefusal(refusal)"
            )
        )
    }

    @Test("⌘↩ Pick up stays unlit on a window it cannot pick up")
    func pickUpUnlitWhenRefused() throws {
        let model = model(Self.blocked())
        model.handle(.openSpace, repeated: false)
        let state = try #require(model.desktops)
        var footer = JumpFooter(
            scope: .desktops,
            overflows: false,
            modifiers: .command,
            desktops: DesktopsFooterState(state)
        )
        #expect(footer.leading == nil)
        let open = DesktopsState(overview: DesktopsStateTests.overview())
        var inside = open
        _ = inside.press(.openSpace, repeated: false)
        footer.desktops = DesktopsFooterState(inside)
        #expect(footer.leading == 2)
    }

    @Test("after a drop the target line is selected")
    func reloadSelectsTheTarget() throws {
        let model = model()
        let overview = DesktopsStateTests.overview()
        let state = DesktopsState(overview: overview)
        let place = DesktopsPlace(screen: 1, desktop: 1, line: 1)
        let target = try #require(state.target(place))
        model.setDesktopsQuery("Safari")
        model.reloadDesktops(selecting: target)
        #expect(model.desktops?.place == place)
        #expect(model.desktops?.isCarrying == false)
        // A search typed before the drop stays (#3165).
        #expect(model.desktops?.query == "Safari")
    }

    /// The plain drop runs ahead of the close and reads the desk
    /// again; Drop & follow keeps its close (#3165).
    @Test("a plain drop is run before the panel would close")
    func plainDropKeepsThePanel() throws {
        let source = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Jump/"
                        + "JumpPanelController+Desktops.swift"
                )
        ).split(whereSeparator: \.isWhitespace).joined()
        let drop = "ifcase.drop(letids,lettarget,follow:false)=action{"
        let keep =
            drop
            + "letfailed=move(ids,to:target,follow:false)"
            + "model.reloadDesktops(selecting:target)"
        let perform = try #require(source.range(of: "funcperform("))
        let body = source[perform.upperBound...]
        let start = try #require(body.range(of: keep))
        let close = try #require(body.range(of: "dismiss("))
        #expect(start.lowerBound < close.lowerBound)
    }
}
