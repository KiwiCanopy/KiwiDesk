import CoreGraphics
import Foundation

/// What a Space Bar drawing reads (#1517): the shelf it sits on
/// and the bar's own style, one value. Member lookup reaches both
/// — their field sets are disjoint by construction
/// (`KiwiShelfParityTests` ▸ `looksAreDisjoint`) — so `look.edge`
/// is the shelf's and `look.showFrontApp` the bar's. A value,
/// never a store: writing through it changes this copy only,
/// which is what a preview or a fixture wants and why the
/// settings keep the two apart.
@dynamicMemberLookup
public struct SpaceBarLook: Sendable, Equatable {
    public var shelf: KiwiShelf
    public var bar: SpaceBarStyle

    public init(
        shelf: KiwiShelf = KiwiShelf(),
        bar: SpaceBarStyle = SpaceBarStyle()
    ) {
        self.shelf = shelf
        self.bar = bar
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

    /// Space identifier font size for a bar depth: the shelf's
    /// size, or half the depth when auto, kept 8 pt inside it.
    public func identifierFontSize(
        forDepth depth: CGFloat
    ) -> CGFloat {
        let base = shelf.fontSize > 0 ? shelf.fontSize : depth * 0.5
        return min(base, max(depth - 8, 8))
    }

    /// App glyph size — a ratio of ONE ladder, so item glyphs,
    /// front-app glyph and identifier never desync (QA
    /// 2026-07-19).
    public func glyphFontSize(forDepth depth: CGFloat) -> CGFloat {
        identifierFontSize(forDepth: depth) * 0.9
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

    public init(
        shelf: KiwiShelf = KiwiShelf(),
        bar: AppBarStyle = AppBarStyle()
    ) {
        self.shelf = shelf
        self.bar = bar
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

    /// Title font size: the shelf's, or auto-scaled with
    /// thickness (`SpaceBarLook.identifierFontSize`).
    public func resolvedFontSize(
        forThickness thickness: CGFloat
    ) -> CGFloat {
        if shelf.fontSize > 0 { return shelf.fontSize }
        return min(max(thickness * 0.42, 9), 28)
    }

    /// Content folded for the shelf's edge: a vertical bar draws
    /// icons only (`Content.rendered(horizontal:)`).
    public var renderedContent: AppBarStyle.Content {
        bar.content.rendered(horizontal: shelf.edge.isHorizontal)
    }

    /// The shelf's corner radius for a thickness.
    public func resolvedCornerRadius(
        forThickness thickness: CGFloat
    ) -> CGFloat {
        shelf.resolvedCornerRadius(forThickness: thickness)
    }
}
