import ApplicationServices
import CoreGraphics

/// A floating resize's write (#2981): the size goes first and the
/// origin follows what the app answered, so a window that refuses
/// the size stays put. Each write judges itself on the app's frame
/// queue; no verdict about the window is stored
/// (`docs/design-decisions.md` ▸ A refused size moves nothing).
enum SizeLedWrite {
    /// What a write needs to judge the answer: where the window
    /// was at the press, and every screen's whole AX frame.
    struct Lead: Equatable {
        let anchor: CGRect
        let screens: [CGRect]
        /// Hears a write whose window macOS says is fixed (#2994), with
        /// the size asked. No part of its identity.
        var fixed: (@Sendable (CGSize) -> Void)?

        static func == (lhs: Lead, rhs: Lead) -> Bool {
            lhs.anchor == rhs.anchor && lhs.screens == rhs.screens
        }
    }

    /// An answer this close to the ask took it: Terminal's cell
    /// grid and mpv's ratio round by a point.
    static let tolerance: CGFloat = 1

    /// How short of a screen's edge a clamped answer can end: the
    /// tallest cell grid seen answered 2 pt short, and a grid may
    /// round down by a whole row.
    static let clampBand: CGFloat = 32

    /// Where the origin belongs for `answer`: on the line from
    /// `anchor` to `asked`, as far along it as the size got. An
    /// axis the press never asked to change keeps the asked origin.
    static func origin(
        asked: CGRect,
        anchor: CGRect,
        answer: CGSize
    ) -> CGPoint {
        CGPoint(
            x: axis(
                asked.minX,
                asked.width,
                anchor.minX,
                anchor.width,
                answer.width
            ),
            y: axis(
                asked.minY,
                asked.height,
                anchor.minY,
                anchor.height,
                answer.height
            )
        )
    }

    private static func axis(
        _ asked: CGFloat,
        _ askedExtent: CGFloat,
        _ anchor: CGFloat,
        _ anchorExtent: CGFloat,
        _ answer: CGFloat
    ) -> CGFloat {
        let wanted = askedExtent - anchorExtent
        guard wanted != 0, abs(answer - askedExtent) > tolerance else {
            return asked
        }
        let share = min(max((answer - anchorExtent) / wanted, 0), 1)
        return (anchor + (asked - anchor) * share).rounded()
    }

    /// Whether macOS could have clamped this size write: a grown
    /// axis whose answer ends at the edge of the screen it starts
    /// on, within a cell grid's rounding. Off every screen, the
    /// answer is yes.
    static func mayClamp(
        _ asked: CGSize,
        answer: CGRect,
        screens: [CGRect]
    ) -> Bool {
        let growsX = asked.width > answer.width + tolerance
        let growsY = asked.height > answer.height + tolerance
        guard growsX || growsY else { return false }
        guard let screen = screens.first(where: { $0.contains(answer.origin) })
        else { return true }
        return (growsX && answer.maxX > screen.maxX - clampBand)
            || (growsY && answer.maxY > screen.maxY - clampBand)
    }

}

extension SizeLedWrite.Lead {
    /// A queued write's share of `write`.
    func write(_ entry: PendingFrames.Entry, _ writer: FrameWriter) {
        write(entry.frame, entry.element, entry.setSize, entry.band, writer)
    }

    /// Writes `frame`, runs on the app's frame queue. A nil read
    /// is no answer, and the frame is written as asked.
    func write(
        _ frame: CGRect,
        _ element: AXUIElement,
        _ setSize: Bool,
        _ band: EdgeBand?,
        _ writer: FrameWriter
    ) {
        func origin(for answer: CGSize) -> CGPoint {
            SizeLedWrite.origin(asked: frame, anchor: anchor, answer: answer)
        }
        guard setSize else {
            let answer = writer.frame(element)?.size ?? frame.size
            writer.setPosition(origin(for: answer), element)
            return
        }
        if band != nil, writer.sizeSettable(element) {
            EdgeBandWrite.lift(
                frame,
                element,
                nearEdgeOf: band,
                writer: writer
            )
        }
        writer.setSize(frame.size, element)
        guard let first = writer.frame(element) else {
            writer.setPosition(frame.origin, element)
            writer.setSize(frame.size, element)
            return
        }
        noteFixed(asked: frame.size, answer: first.size, element, writer)
        let held = origin(for: first.size)
        guard
            held != frame.origin,
            SizeLedWrite.mayClamp(frame.size, answer: first, screens: screens),
            writer.sizeSettable(element)
        else {
            writer.setPosition(held, element)
            writer.setSize(frame.size, element)
            return
        }
        writer.setPosition(frame.origin, element)
        writer.setSize(frame.size, element)
        if let second = writer.frame(element) {
            let settled = origin(for: second.size)
            if settled != frame.origin {
                writer.setPosition(settled, element)
            }
        }
    }

    /// Asks macOS only where the answer stayed at the anchor, so a
    /// window that took the size pays no read.
    private func noteFixed(
        asked: CGSize,
        answer: CGSize,
        _ element: AXUIElement,
        _ writer: FrameWriter
    ) {
        guard let fixed else { return }
        let tolerance = SizeLedWrite.tolerance
        let width = abs(asked.width - anchor.width) > tolerance
        let height = abs(asked.height - anchor.height) > tolerance
        guard width || height,
            abs(answer.width - anchor.width) <= tolerance,
            abs(answer.height - anchor.height) <= tolerance,
            !writer.sizeSettable(element)
        else { return }
        fixed(asked)
    }
}
