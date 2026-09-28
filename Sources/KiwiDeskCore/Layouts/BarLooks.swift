import CoreGraphics
import Foundation

/// What a Space Bar drawing reads (#1517): the shelf it sits on
/// and the bar's own style, one value. Member lookup reaches both
/// — their field sets are disjoint by construction
/// (`KiwiShelfParityTests` ▸ `looksAreDisjoint`) — so
/// `look.thickness` is the shelf's and `look.edge` the bar's. A value,
/// never a store: writing through it changes this copy only,
/// which is what a preview or a fixture wants and why the
/// settings keep the two apart.
@dynamicMemberLookup
public struct SpaceBarLook: Sendable, Equatable {
    public var shelf: KiwiShelf
    public var bar: SpaceBarStyle
    /// `border.sheen` (#1644), which paints the highlight and the
    /// shelf's border.
    public var sheen: CGFloat

    public init(shelf: KiwiShelf, bar: SpaceBarStyle, sheen: CGFloat) {
        self.shelf = shelf
        self.bar = bar
        self.sheen = sheen
    }

    /// A placeholder until a view is handed its look: defaults,
    /// no sheen.
    init() {
        self.init(shelf: KiwiShelf(), bar: SpaceBarStyle(), sheen: 0)
    }

    public subscript<T>(
        dynamicMember path: WritableKeyPath<KiwiShelf, T>
    ) -> T {
        get { shelf[keyPath: path] }
        set { shelf[keyPath: path] = newValue }
    }

    public subscript<T>(
        dynamicMember path: KeyPath<KiwiShelf, T>
    ) -> T { shelf[keyPath: path] }

    public subscript<T>(
        dynamicMember path: WritableKeyPath<SpaceBarStyle, T>
    ) -> T {
        get { bar[keyPath: path] }
        set { bar[keyPath: path] = newValue }
    }

    public subscript<T>(
        dynamicMember path: KeyPath<SpaceBarStyle, T>
    ) -> T { bar[keyPath: path] }

    /// The depth an item's content is sized to on a strip `depth`
    /// deep — the shelf's one derivation (#1682).
    public func contentDepth(forDepth depth: CGFloat) -> CGFloat {
        shelf.contentDepth(forDepth: depth)
    }

    /// Space identifier font size on a strip `depth` deep, the
    /// glyph size taken inside (#1713).
    public func identifierFontSize(forDepth depth: CGFloat) -> CGFloat {
        identifierFontSize(forContentDepth: contentDepth(forDepth: depth))
    }

    /// App glyph size on a strip `depth` deep.
    public func glyphFontSize(forDepth depth: CGFloat) -> CGFloat {
        glyphFontSize(forContentDepth: contentDepth(forDepth: depth))
    }

    /// Front-app title size on a strip `depth` deep.
    public func titleFontSize(forDepth depth: CGFloat) -> CGFloat {
        titleFontSize(forContentDepth: contentDepth(forDepth: depth))
    }

    /// Space identifier font size for a depth that is ALREADY
    /// content — a schematic's; a live bar takes `forDepth:`. The
    /// shelf's size, or half the content when auto, kept 8 pt
    /// inside it.
    public func identifierFontSize(
        forContentDepth content: CGFloat
    ) -> CGFloat {
        let base =
            shelf.fontSize > 0 ? shelf.fontSize : content * 0.5
        return min(base, max(content - 8, 8))
    }

    /// App glyph size — a ratio of ONE ladder, so item glyphs,
    /// front-app glyph and identifier never desync (QA
    /// 2026-07-19).
    public func glyphFontSize(
        forContentDepth content: CGFloat
    ) -> CGFloat {
        identifierFontSize(forContentDepth: content) * 0.9
    }

    /// The front-app segment's title size for a content depth:
    /// the shelf's, or auto at `KiwiShelf.autoTitleShare`,
    /// unclamped — the App Bar's title clamps, this one does not
    /// (#1682).
    public func titleFontSize(
        forContentDepth content: CGFloat
    ) -> CGFloat {
        shelf.fontSize > 0
            ? shelf.fontSize : content * KiwiShelf.autoTitleShare
    }

    /// The shelf's corner radius for a thickness.
    public func resolvedCornerRadius(
        forThickness thickness: CGFloat
    ) -> CGFloat {
        shelf.resolvedCornerRadius(forThickness: thickness)
    }
}

/// What an App Bar drawing reads (#1517): the shelf and the bar's
/// own style after its layout's overrides — `SpaceBarLook`'s
/// twin, with the same member lookup and the same value-only
/// contract.
@dynamicMemberLookup
public struct AppBarLook: Sendable, Equatable {
    public var shelf: KiwiShelf
    public var bar: AppBarStyle
    /// `border.sheen` (#1644), which paints the highlight and the
    /// shelf's border.
    public var sheen: CGFloat

    public init(shelf: KiwiShelf, bar: AppBarStyle, sheen: CGFloat) {
        self.shelf = shelf
        self.bar = bar
        self.sheen = sheen
    }

    /// A placeholder until a view is handed its look: defaults,
    /// no sheen.
    init() {
        self.init(shelf: KiwiShelf(), bar: AppBarStyle(), sheen: 0)
    }

    public subscript<T>(
        dynamicMember path: WritableKeyPath<KiwiShelf, T>
    ) -> T {
        get { shelf[keyPath: path] }
        set { shelf[keyPath: path] = newValue }
    }

    public subscript<T>(
        dynamicMember path: KeyPath<KiwiShelf, T>
    ) -> T { shelf[keyPath: path] }

    public subscript<T>(
        dynamicMember path: WritableKeyPath<AppBarStyle, T>
    ) -> T {
        get { bar[keyPath: path] }
        set { bar[keyPath: path] = newValue }
    }

    public subscript<T>(
        dynamicMember path: KeyPath<AppBarStyle, T>
    ) -> T { bar[keyPath: path] }

    /// The depth an item's content is sized to on a strip `depth`
    /// deep — the shelf's one derivation (#1682).
    public func contentDepth(forDepth depth: CGFloat) -> CGFloat {
        shelf.contentDepth(forDepth: depth)
    }

    /// Title font size on a strip `depth` deep, the glyph size
    /// taken inside (#1713).
    public func resolvedFontSize(forDepth depth: CGFloat) -> CGFloat {
        resolvedFontSize(forContentDepth: contentDepth(forDepth: depth))
    }

    /// Title font size for a depth that is ALREADY content — a
    /// schematic's; a live bar takes `forDepth:`. The shelf's, or
    /// auto at `KiwiShelf.autoTitleShare`, clamped 9–28.
    public func resolvedFontSize(
        forContentDepth content: CGFloat
    ) -> CGFloat {
        if shelf.fontSize > 0 { return shelf.fontSize }
        return min(max(content * KiwiShelf.autoTitleShare, 9), 28)
    }

    /// Content folded for the bar's edge: a vertical bar draws
    /// icons only (`Content.rendered(horizontal:)`).
    public var renderedContent: AppBarStyle.Content {
        bar.content.rendered(horizontal: bar.edge.isHorizontal)
    }

    /// The shelf's corner radius for a thickness.
    public func resolvedCornerRadius(
        forThickness thickness: CGFloat
    ) -> CGFloat {
        shelf.resolvedCornerRadius(forThickness: thickness)
    }
}
