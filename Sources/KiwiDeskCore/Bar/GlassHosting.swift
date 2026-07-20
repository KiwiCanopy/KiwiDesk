import Foundation

/// The single mode naming where a bar item lives for one render
/// (#407). A bar item physically sits in one of these parentings
/// depending on the resolved style; before #407 no value named the
/// current/target mode, so every entry point independently tore
/// down the *other* modes. Now one `resolve` per render feeds one
/// dispatch (`prepareGlassHosting` tears down the non-target modes,
/// `installGlassHosting` installs the target), so the "who tears
/// down whom" invariant lives in one place. Shared by both bars.
enum GlassHosting: Equatable {
    /// No glass finish: the solid `plain` plate or the per-item
    /// `boxed` fill. Items ride `itemContainer` on the panel.
    case plainPlate
    /// Plain + glass, the run fits: the glass hugs the run wrapper.
    case plainGlassHug
    /// Plain + glass, the run overflows: the glass spans the
    /// scrolling item viewport (`itemContainer`).
    case plainGlassSpan
    /// Boxed + glass: each item hosted in its own glass box.
    case boxGlass
    /// Below macOS 26 — glass can't render, so nothing is hosted.
    /// Same parenting as `plainPlate` (items in `itemContainer`);
    /// named apart so the dispatch documents the below-26 reality.
    case none

    /// The one hosting mode for this render. `available` is the OS
    /// gate (`glassAvailable`); `glassEnabled` the resolved finish;
    /// `boxed` the shape; `overflow` whether the run scrolls (only
    /// splits plain + glass into hug vs span). One authority so the
    /// two bars can't drift on the decision.
    static func resolve(
        available: Bool,
        glassEnabled: Bool,
        boxed: Bool,
        overflow: Bool
    ) -> GlassHosting {
        guard available else { return .none }
        guard glassEnabled else { return .plainPlate }
        if boxed { return .boxGlass }
        return overflow ? .plainGlassSpan : .plainGlassHug
    }
}
