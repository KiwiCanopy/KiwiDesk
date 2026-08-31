import Foundation

/// Bar item hierarchy hosting mode for liquid glass finishes
/// (#407): one `resolve` per render feeds one dispatch, so the
/// "who tears down whom" invariant lives in ONE place — before
/// this, every entry point tore down the other modes itself.
enum GlassHosting: Equatable {
    /// Solid plain plate or per-item boxed fill.
    case plainPlate
    /// Plain glass hugging run wrapper.
    case plainGlassHug
    /// Plain glass spanning scrolling viewport.
    case plainGlassSpan
    /// Boxed glass per item.
    case boxGlass
    /// Unsupported OS version (below macOS 26) fallback.
    case none

    /// Resolves the single hosting mode for a bar render — one
    /// authority so the two bars can't drift (#407).
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
