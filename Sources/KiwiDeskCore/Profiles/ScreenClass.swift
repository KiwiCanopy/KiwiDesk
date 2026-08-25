import CoreGraphics
import Foundation

/// What SHAPE a display is, which is what decides the layouts a
/// starter setup gives it (#678 Phase 4 pass 11, turn 15b).
///
/// Measured in **points**, never pixels. A 5K 27" and a 1440p 27"
/// both report 2560 pt and want identical layouts, while a Retina
/// laptop reports 1728 pt and wants laptop layouts despite having
/// more pixels than either. `Display.frame` is already the point
/// space windows are laid out in, so it is the one input.
///
/// The four cases are disjoint only because they are tested in
/// the order `allCases` lists them — `pivoted` before `ultrawide`
/// before `laptop` — so a case added here states where in that
/// order it goes. `ScreenClassTests` pins the order and the
/// boundaries.
public enum ScreenClass: String, Sendable, CaseIterable, Codable {
    /// Taller than wide. Detected by aspect rather than size:
    /// `height > width` is unambiguous and needs no threshold.
    case pivoted
    /// Wide enough to hold three or four full columns.
    case ultrawide
    /// Too narrow for a two-way split to leave usable halves.
    case laptop
    /// The 2K / 4K middle, where most desktop layouts work.
    case desktop

    /// At or above this width a screen is `ultrawide` whatever
    /// its aspect — 3440 pt holds three or four full columns.
    public static let ultrawideWidth: CGFloat = 3000
    /// …as is anything this wide relative to its height, which
    /// catches a short ultrawide that misses the width test.
    public static let ultrawideAspect: CGFloat = 2.1
    /// Below this width a two-way split leaves 864 pt per window
    /// and a three-window BSP is already under the 300 pt
    /// minimum in one axis — tiling that fights you.
    public static let laptopWidth: CGFloat = 1900

    /// The verdict for a size in points. Sizes with a
    /// non-positive dimension answer `desktop`: nothing sensible
    /// can be derived from them, and the caller that produced one
    /// has a worse problem than its layout list.
    public static func of(_ size: CGSize) -> ScreenClass {
        guard size.width > 0, size.height > 0 else { return .desktop }
        if size.height > size.width { return .pivoted }
        if size.width >= ultrawideWidth
            || size.width / size.height >= ultrawideAspect
        {
            return .ultrawide
        }
        if size.width < laptopWidth { return .laptop }
        return .desktop
    }

    /// The verdict for a connected display. Reads `frame`, not
    /// `visibleFrame`: the menu bar and the Dock are chrome the
    /// user can move or hide, and a screen does not change shape
    /// when they do.
    public static func of(_ display: Display) -> ScreenClass {
        of(display.frame.size)
    }

    /// The layouts this shape benefits from, **best first**, so a
    /// screen granted a share of *n* takes the first *n* behind
    /// its lead.
    ///
    /// **The first space is not drawn from this list**, in the
    /// same way and for the same reason `floating` is not in it
    /// (below): what a screen OPENS in depends on the other
    /// screens — the narrowest leads Monocle and the rest lead
    /// Scrolling — which is a rule about the SETUP that no single
    /// shape can answer. `StarterAllocation.lead(_:of:)` owns it
    /// end to end, and it can hand Monocle to a shape this list
    /// leaves it out of.
    ///
    /// Absences are as deliberate as the entries. `track` is out
    /// of `desktop` — a layout no one uses is worse than one they
    /// discover later — and out of `laptop`, which has no width
    /// to give it. `monocle` is out of `desktop` and `ultrawide`,
    /// which are the shapes that least need it. `bsp` appears
    /// only under `desktop`, the one class wide enough to take
    /// four windows before anything gets cramped; at 3440 pt it
    /// produces absurd 1700 pt-wide windows and at 1728 pt it
    /// produces unusable ones.
    ///
    /// **`floating` is not in any list**, deliberately. It is not
    /// a layout a shape wants more or less of — every setup gets
    /// exactly one Floating space and it goes on the largest
    /// screen with room beside it, which is a rule about the
    /// SETUP rather than about a screen. `StarterAllocation` owns
    /// it end to end.
    ///
    /// It used to sit last in all four lists and the allocator
    /// filtered it back out before reading them, so the entry and
    /// its position were decorative — and the guard pinning
    /// "floating is always last" passed on data no production
    /// path consumed (architect review, 2026-08-11).
    public var layouts: [LayoutMode] {
        switch self {
        case .laptop:
            // Scrolling is the real laptop answer: full-width
            // windows, one keystroke apart. Monocle is what a
            // small screen is best at.
            [.scrolling, .monocle]
        case .desktop:
            // Grid leads because it is the one you can predict —
            // two windows are two halves, four are quarters.
            [.grid, .stack, .bsp, .scrolling]
        case .ultrawide:
            // Track is why Track exists. Grid replaces Scrolling,
            // which solves "not enough width" — the one problem
            // this screen does not have.
            [.track, .grid, .stack]
        case .pivoted:
            // Everything that assumes width has to flip; a
            // pivoted screen is usually the reference screen
            // (docs, logs, chat), so Monocle belongs too.
            [.stack, .grid, .monocle]
        }
    }
}
