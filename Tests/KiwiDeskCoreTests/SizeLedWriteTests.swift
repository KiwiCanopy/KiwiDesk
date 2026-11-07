import ApplicationServices
import CoreGraphics
import Foundation
import Testing
import os

@testable import KiwiDeskCore

/// A floating resize's origin follows the app's answer to the size
/// (#2981). `SizeLedApp` answers as the device did on 2026-11-04,
/// macOS 27: Digital Color Meter refuses both axes, mpv keeps its
/// ratio, and every app's size write stops at the screen's right
/// and bottom edges while its origin has not moved.
final class SizeLedApp: Sendable {
    enum Kind: Sendable {
        case free, fixed, fixedWidth, ratio, atMaximum, grid
    }

    let frame: OSAllocatedUnfairLock<CGRect>
    let kind: Kind
    let screen: CGRect
    let writes = OSAllocatedUnfairLock<[String]>(initialState: [])

    init(_ frame: CGRect, _ kind: Kind, screen: CGRect) {
        self.frame = OSAllocatedUnfairLock(initialState: frame)
        self.kind = kind
        self.screen = screen
    }

    private func setSize(_ asked: CGSize) {
        writes.withLock { $0.append("size") }
        frame.withLock { now in
            switch kind {
            case .fixed:
                return
            case .fixedWidth:
                now.size.height = min(asked.height, screen.maxY - now.minY)
            case .grid:
                now.size.width = asked.width
                now.size.height = (asked.height / 17).rounded(.down) * 17
            case .free:
                now.size.width = min(asked.width, screen.maxX - now.minX)
                now.size.height = min(asked.height, screen.maxY - now.minY)
            case .atMaximum:
                now.size.width = min(asked.width, now.width)
                now.size.height = min(asked.height, now.height)
            case .ratio:
                let scale = min(
                    asked.width / now.width,
                    asked.height / now.height,
                    1
                )
                now.size.width *= scale
                now.size.height *= scale
            }
        }
    }

    var writer: FrameWriter {
        FrameWriter(
            setFrame: { rect, _ in
                self.setSize(rect.size)
                self.frame.withLock { $0.origin = rect.origin }
                self.setSize(rect.size)
            },
            setPosition: { point, _ in
                self.writes.withLock { $0.append("position") }
                self.frame.withLock { $0.origin = point }
            },
            writeEUI: { _, _ in },
            frame: { _ in self.frame.withLock { $0 } },
            setSize: { size, _ in self.setSize(size) },
            sizeSettable: { _ in self.kind != .fixed }
        )
    }

    var now: CGRect { frame.withLock { $0 } }
}

@Suite("A floating resize's origin follows the app's answer (#2981)")
@MainActor
struct SizeLedWriteTests {
    private let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    private let start = CGRect(x: 300, y: 200, width: 400, height: 300)

    private var element: AXUIElement {
        AXUIElementCreateApplication(getpid())
    }

    private func write(
        _ frame: CGRect,
        to app: SizeLedApp,
        from anchor: CGRect,
        setSize: Bool = true,
        band: EdgeBand? = nil
    ) {
        SizeLedWrite.Lead(anchor: anchor, screens: [screen]).write(
            frame,
            element,
            setSize,
            band,
            app.writer
        )
    }

    @Test("The origin sits as far along the line as the size got")
    func originLine() {
        let asked = CGRect(x: 275, y: 200, width: 450, height: 300)
        let at = { (width: CGFloat) in
            SizeLedWrite.origin(
                asked: asked,
                anchor: start,
                answer: CGSize(width: width, height: 300)
            ).x
        }
        expectEqual(at(450), 275)
        expectEqual(at(400), 300)
        expectEqual(at(420), 290)
        // A ratio app answering below the anchor stays at the anchor,
        // and a point of rounding counts as the ask.
        expectEqual(at(380), 300)
        expectEqual(at(449), 275)
    }

    @Test("An axis the run never asked to change keeps the asked origin")
    func unaskedAxis() {
        let asked = CGRect(x: 275, y: 190, width: 450, height: 300)
        let origin = SizeLedWrite.origin(
            asked: asked,
            anchor: start,
            answer: CGSize(width: 450, height: 180)
        )
        expectEqual(origin, asked.origin)
    }

    @Test("A fixed window keeps its origin on every grow and shrink")
    func fixedStays() {
        let app = SizeLedApp(start, .fixed, screen: screen)
        for frame in [
            CGRect(x: 275, y: 200, width: 450, height: 300),
            CGRect(x: 325, y: 200, width: 350, height: 300),
            CGRect(x: 300, y: 175, width: 400, height: 350),
            CGRect(x: 300, y: 225, width: 400, height: 250),
        ] {
            write(frame, to: app, from: start)
            expectEqual(app.now, start)
        }
    }

    @Test("A free window lands on the asked frame")
    func freeLands() {
        let app = SizeLedApp(start, .free, screen: screen)
        let asked = CGRect(x: 275, y: 200, width: 450, height: 300)
        write(asked, to: app, from: start)
        expectEqual(app.now, asked)
        expectEqual(app.writes.withLock { $0 }, ["size", "position", "size"])
    }

    @Test("A window fixed on one axis still takes the other")
    func oneAxisFixed() {
        let app = SizeLedApp(start, .fixedWidth, screen: screen)
        write(
            CGRect(x: 275, y: 200, width: 450, height: 300),
            to: app,
            from: start
        )
        expectEqual(app.now, start)
        let taller = CGRect(x: 300, y: 175, width: 400, height: 350)
        write(taller, to: app, from: start)
        expectEqual(app.now, taller)
    }

    @Test("A ratio app's shrink keeps its origin move, its grow does not")
    func ratioApp() {
        let app = SizeLedApp(start, .ratio, screen: screen)
        write(
            CGRect(x: 275, y: 200, width: 450, height: 300),
            to: app,
            from: start
        )
        expectEqual(app.now, start)
        write(
            CGRect(x: 325, y: 200, width: 350, height: 300),
            to: app,
            from: start
        )
        expectEqual(app.now.minX, 325)
        expectEqual(app.now.width, 350)
    }

    @Test("A free window against the right edge grows to the left")
    func clampedGrowMoves() {
        let flush = CGRect(x: 1328, y: 200, width: 400, height: 300)
        let app = SizeLedApp(flush, .free, screen: screen)
        let asked = CGRect(x: 1278, y: 200, width: 450, height: 300)
        write(asked, to: app, from: flush)
        expectEqual(app.now, asked)
    }

    @Test("A free window against the bottom edge grows upward")
    func clampedGrowMovesUp() {
        let flush = CGRect(x: 300, y: 817, width: 400, height: 300)
        let app = SizeLedApp(flush, .free, screen: screen)
        let asked = CGRect(x: 300, y: 767, width: 400, height: 350)
        write(asked, to: app, from: flush)
        expectEqual(app.now, asked)
    }

    @Test("A fixed window against an edge never leaves it")
    func clampedFixedStays() {
        let flush = CGRect(x: 1328, y: 200, width: 400, height: 300)
        let app = SizeLedApp(flush, .fixed, screen: screen)
        write(
            CGRect(x: 1278, y: 200, width: 450, height: 300),
            to: app,
            from: flush
        )
        expectEqual(app.now, flush)
        #expect(
            app.writes.withLock { $0 } == ["size", "position", "size"]
        )
    }

    @Test("A settable window that stays short at an edge comes back")
    func clampedShortReturns() {
        let flush = CGRect(x: 1328, y: 200, width: 400, height: 300)
        let app = SizeLedApp(flush, .fixedWidth, screen: screen)
        write(
            CGRect(x: 1278, y: 200, width: 450, height: 300),
            to: app,
            from: flush
        )
        expectEqual(app.now, flush)
        #expect(
            app.writes.withLock { $0 }
                == ["size", "position", "size", "position"]
        )
    }

    @Test("A free window with some room grows past the clamp")
    func partlyClamped() {
        let near = CGRect(x: 1300, y: 200, width: 400, height: 300)
        let app = SizeLedApp(near, .free, screen: screen)
        let asked = CGRect(x: 1228, y: 200, width: 500, height: 300)
        write(asked, to: app, from: near)
        expectEqual(app.now, asked)
    }

    @Test("A shrink in the band lifts a settable window, never a fixed one")
    func bandLift() {
        let edgeBand = EdgeBand(screen: screen, bottom: true, right: true)
        let low = CGRect(x: 300, y: 817, width: 400, height: 300)
        let asked = CGRect(x: 300, y: 822, width: 400, height: 290)
        let free = SizeLedApp(low, .free, screen: screen)
        write(asked, to: free, from: low, band: edgeBand)
        expectEqual(free.writes.withLock { $0 }.first, "position")
        expectEqual(free.now, asked)
        let fixed = SizeLedApp(low, .fixed, screen: screen)
        write(asked, to: fixed, from: low, band: edgeBand)
        expectEqual(fixed.writes.withLock { $0 }.first, "size")
        expectEqual(fixed.now, low)
    }

    @Test("A spring's position-only frame follows the same answer")
    func positionOnly() {
        let app = SizeLedApp(start, .fixed, screen: screen)
        write(
            CGRect(x: 290, y: 200, width: 400, height: 300),
            to: app,
            from: CGRect(x: 300, y: 200, width: 380, height: 300),
            setSize: false
        )
        expectEqual(app.writes.withLock { $0 }, ["position"])
        expectEqual(app.now.minX, 290)
        app.frame.withLock { $0 = start }
        write(
            CGRect(x: 290, y: 200, width: 420, height: 300),
            to: app,
            from: start,
            setSize: false
        )
        expectEqual(app.now, start)
    }

    @Test("No read means no answer, so the frame is written as asked")
    func noRead() {
        let log = OSAllocatedUnfairLock<[String]>(initialState: [])
        let writer = FrameWriter(
            setFrame: { _, _ in log.withLock { $0.append("frame") } },
            setPosition: { _, _ in log.withLock { $0.append("position") } },
            writeEUI: { _, _ in },
            setSize: { _, _ in log.withLock { $0.append("size") } }
        )
        SizeLedWrite.Lead(anchor: start, screens: [screen]).write(
            CGRect(x: 275, y: 200, width: 450, height: 300),
            element,
            true,
            nil,
            writer
        )
        expectEqual(log.withLock { $0 }, ["size", "position", "size"])
    }

    @Test("A clamp needs a grown axis ending at the window's screen edge")
    func clampPredicate() {
        let clamps = {
            (asked: CGSize, answer: CGRect, screens: [CGRect]) in
            SizeLedWrite.mayClamp(asked, answer: answer, screens: screens)
        }
        let wide = CGSize(width: 450, height: 300)
        let tall = CGSize(width: 400, height: 350)
        #expect(!clamps(wide, start, [screen]))
        #expect(
            clamps(wide, start.offsetBy(dx: 1028, dy: 0), [screen])
        )
        #expect(
            clamps(tall, start.offsetBy(dx: 0, dy: 617), [screen])
        )
        // Short of the edge by more than a grid's rounding is a
        // refusal; a grown height says nothing about the right edge.
        #expect(
            !clamps(wide, start.offsetBy(dx: 900, dy: 0), [screen])
        )
        #expect(
            !clamps(tall, start.offsetBy(dx: 1028, dy: 0), [screen])
        )
        // A shrink is never clamped, and off every screen says yes.
        #expect(
            !clamps(
                CGSize(width: 300, height: 200),
                start.offsetBy(dx: 1028, dy: 617),
                [screen]
            )
        )
        #expect(clamps(wide, start, []))
        #expect(!clamps(CGSize(width: 300, height: 200), start, []))
    }
}
