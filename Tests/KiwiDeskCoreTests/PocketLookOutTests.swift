import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A full Pocket's kiwis look out exactly as far as an empty one's
/// (#3480, ruling back #3446): holding something lights the tab
/// (#3384) and moves nothing. A shape clause — held against empty —
/// never the look-out's value, which a retune may move.
@Suite(
    "Pocket handle look-out, held or empty (#3480)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct PocketLookOutTests {
    /// The kiwis' topmost inked row, in points from the top, of a
    /// bottom-edge handle drawn at 2x (ink rows read at a fixed
    /// scale, alpha over 0.5).
    private func kiwiTop(holds: Bool) throws -> CGFloat {
        let height: CGFloat = 20
        let size = CGSize(width: 40, height: height)
        let view = PocketHandleView(frame: CGRect(origin: .zero, size: size))
        view.appearance = NSAppearance(named: .darkAqua)
        view.holds = holds
        view.wear(
            KiwiShelf(),
            markHex: "#FF0000",
            edge: .bottom,
            kiwisOut: false
        )
        let scale: CGFloat = 2
        let rep = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(size.width * scale),
                pixelsHigh: Int(size.height * scale),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        )
        rep.size = size
        view.cacheDisplay(in: view.bounds, to: rep)
        // Above the tab only the kiwis draw.
        let depth = PocketHandleView.tabDepth(of: KiwiShelf())
        let tabTop = Int((height - depth) * scale)
        for y in 0..<tabTop {
            for x in 0..<rep.pixelsWide {
                if let c = rep.colorAt(x: x, y: y), c.alphaComponent > 0.5 {
                    return CGFloat(y) / scale
                }
            }
        }
        Issue.record("no kiwis drawn")
        return .nan
    }

    @Test("a held pocket's kiwis stand where an empty one's do")
    func heldLooksOutAsEmpty() throws {
        let empty = try kiwiTop(holds: false)
        let held = try kiwiTop(holds: true)
        #expect(!empty.isNaN)
        #expect(abs(empty - held) < 0.5, "empty \(empty), held \(held)")
    }
}
