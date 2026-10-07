import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A peek taller than its room (#1946, owner rulings): the panel is
/// capped to the usable area away from the bar, and the list keeps
/// the windows that fit, marking the cut — at the far edge from the
/// bar — with a chevron pointing at the rest and their count, a
/// button opening the menu (`BarPeekActionTests`).
@Suite("Bar hover peek fit", .serialized)
@MainActor
struct BarPeekFitTests {
    init() {
        LiquidGlassGate.override = { false }
    }

    /// A row of `app`'s process — one pid per app name unless
    /// `pid` says otherwise.
    private func row(
        _ id: UInt32,
        app: String,
        title: String,
        icon: NSImage? = nil,
        pid: pid_t? = nil
    ) -> BarWindowRow {
        BarWindowRow(
            window: WindowID(id),
            pid: pid ?? pid_t(app.unicodeScalars.map(\.value).reduce(0, +)),
            app: app,
            title: title,
            icon: icon
        )
    }

    /// A list taller than its room keeps the windows that fit, in
    /// order, and closes on the "more" line with the rest's count;
    /// the header still counts every window (owner ruling, #1946).
    @Test("A tall peek keeps what fits and says how many more")
    func tallPeekKeepsWhatFits() throws {
        LocalizationManager.shared.select("en")
        let content = BarPeekContent(
            rows: (1...14).map {
                row(UInt32($0), app: "Notes", title: "Note \($0)")
            }
        )
        let body = BarPeekBody()
        let whole = body.build(content, shelf: KiwiShelf())
        #expect(body.moreLabel == nil, "a list that fits says nothing")
        let room: CGFloat = 200
        #expect(whole.height > room)
        let size = body.build(content, shelf: KiwiShelf(), maxHeight: room)
        #expect(size.height <= room)
        let titles = body.labels.dropFirst().map(\.stringValue)
        #expect(!titles.isEmpty)
        #expect(titles == (1...titles.count).map { "Note \($0)" })
        let more = try #require(body.moreLabel)
        #expect(more.stringValue == "\(14 - titles.count) more")
        #expect(
            more.textColor == NSColor(kiwiHex: KiwiShelf().idleItemColor)
        )
        // The chevron points down at the rows cut below.
        #expect(body.moreChevron?.identifier?.rawValue == "chevron.down")
        #expect(body.pills.map(\.number.stringValue) == ["14"])
        #expect(more.frame.maxY <= size.height)
        let lastTitle = try #require(body.labels.last)
        #expect(more.frame.minY > lastTitle.frame.maxY, "the cut is below")
    }

    /// Over a bottom bar the cut is at the far, TOP edge: the peek
    /// keeps the windows nearest the bar, the last ones, and the
    /// chevron above them points up at the rest.
    @Test("Over a bottom bar it keeps the last windows, chevron up")
    func bottomBarCutsAtTheTop() throws {
        LocalizationManager.shared.select("en")
        let content = BarPeekContent(
            rows: (1...14).map {
                row(UInt32($0), app: "Notes", title: "Note \($0)")
            }
        )
        let body = BarPeekBody()
        let size = body.build(
            content,
            shelf: KiwiShelf(),
            maxHeight: 200,
            cutAtTop: true
        )
        #expect(size.height <= 200)
        let titles = body.labels.dropFirst().map(\.stringValue)
        #expect(!titles.isEmpty)
        let first = 14 - titles.count + 1
        #expect(titles == (first...14).map { "Note \($0)" })
        let more = try #require(body.moreLabel)
        #expect(more.stringValue == "\(first - 1) more")
        #expect(body.moreChevron?.identifier?.rawValue == "chevron.up")
        let header = try #require(body.labels.first)
        #expect(more.frame.maxY < header.frame.minY, "the cut is above")
    }

    /// The truncation keeps order across groups and each group's
    /// whole count.
    @Test("Keeping the first windows keeps every group's count")
    func keepingKeepsCounts() {
        let content = BarPeekContent(
            rows: [
                row(1, app: "A", title: "1"),
                row(2, app: "A", title: "2"),
                row(3, app: "B", title: "3"),
                row(4, app: "B", title: "4"),
            ]
        )
        let kept = content.keeping(3)
        #expect(kept.groups.map(\.titles) == [["1", "2"], ["3"]])
        #expect(kept.groups.map(\.count) == [2, 2])
        #expect(kept.windowCount == 4)
        #expect(content.keeping(1).groups.map(\.app) == ["A"])
        let tail = content.keeping(3, fromEnd: true)
        #expect(tail.groups.map(\.titles) == [["2"], ["3", "4"]])
        #expect(tail.groups.map(\.count) == [2, 2])
    }

    /// A peek taller than the usable room on its side is cut to it,
    /// so it never covers its bar; one that fits keeps its height.
    @Test("A tall peek is capped to the usable area")
    func tallPeekIsCapped() {
        // The menu bar and the Dock leave a smaller usable area.
        let visible = CGRect(x: 0, y: 80, width: 1440, height: 790)
        let top = CGRect(x: 0, y: 830, width: 1440, height: 40)
        let tall = CGSize(width: 200, height: 2000)
        let capped = BarPeekPanel.capped(
            tall,
            edge: .top,
            strip: top,
            visible: visible
        )
        #expect(capped.width == tall.width)
        #expect(capped.height < tall.height)
        let origin = BarPeekPanel.origin(
            size: capped,
            edge: .top,
            anchor: CGRect(x: 300, y: 840, width: 20, height: 20),
            strip: top,
            visible: visible
        )
        #expect(origin.y >= visible.minY)
        #expect(origin.y + capped.height <= top.minY)
        let bottom = CGRect(x: 0, y: 80, width: 1440, height: 40)
        let up = BarPeekPanel.capped(
            tall,
            edge: .bottom,
            strip: bottom,
            visible: visible
        )
        #expect(bottom.maxY + up.height <= visible.maxY)
        let small = CGSize(width: 200, height: 80)
        #expect(
            BarPeekPanel.capped(
                small,
                edge: .top,
                strip: top,
                visible: visible
            ) == small
        )
    }

    /// "N more" counts the rows the cut hid, and only those (owner
    /// ruling amendment 2): a lone window titled as its app above
    /// the cut is a drawn row, so it is never counted as hidden.
    @Test("N more counts exactly the rows the cut hid")
    func moreCountsHiddenRows() throws {
        LocalizationManager.shared.select("en")
        let content = BarPeekContent(
            rows: [row(1, app: "Claude", title: "Claude")]
                + (2...15).map {
                    row(UInt32($0), app: "Notes", title: "Note \($0)")
                }
        )
        let body = BarPeekBody()
        _ = body.build(content, shelf: KiwiShelf(), maxHeight: 200)
        let more = try #require(body.moreLabel, "the list was cut")
        let rows = content.groups.flatMap(\.titles).count
        let drawn = body.targets.filter { $0.action != .more }.count
        #expect(body.labels.contains { $0.stringValue == "Claude" })
        #expect(drawn > 1, "the lone window's row is above the cut")
        #expect(more.stringValue == "\(rows - drawn) more")
        #expect(rows - drawn == 15 - drawn, "every window is a row")
    }
}
