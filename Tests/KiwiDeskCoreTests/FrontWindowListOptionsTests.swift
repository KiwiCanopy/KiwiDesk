import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The front-to-back read's options (#2103): macOS counts a
/// below-normal bar such as SketchyBar's (layer −20) among the
/// desktop's elements, so the read KiwiVision's mask and the Never
/// dimmed picker take keeps them, while every other reader leaves
/// the desktop out. Measured 2026-10-16 on macOS 27: 43 SketchyBar
/// windows on screen, none with the desktop excluded.
@Suite("Front window list options")
struct FrontWindowListOptionsTests {
    @Test("the desktop's elements are kept only when asked for")
    func desktopElements() {
        let kept = FloatDetection.listOptions(includingDesktopElements: true)
        #expect(kept.contains(.optionOnScreenOnly))
        #expect(!kept.contains(.excludeDesktopElements))
        let left = FloatDetection.listOptions(includingDesktopElements: false)
        #expect(left.contains(.optionOnScreenOnly))
        #expect(left.contains(.excludeDesktopElements))
    }
}
