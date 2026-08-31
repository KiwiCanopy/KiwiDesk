import Foundation

/// Bar item hierarchy hosting mode for liquid glass finishes (#407).
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

    /// Resolves single hosting mode for bar render (#407).
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
