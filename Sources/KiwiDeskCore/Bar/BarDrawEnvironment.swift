import AppKit

/// What a bar draw reads beyond the input it is shown (#1901): an
/// overlay skips a show whose input AND environment repeat, so a
/// draw-time read belongs here or the skip keeps the old drawing
/// (bars.md). Read once per show; every field is cheap.
struct BarDrawEnvironment: Equatable {
    /// Liquid Glass after Reduce transparency (#1374).
    let glass: Bool
    /// Bumped by `BarFont.invalidate` when the font set changes.
    let fonts: Int
    /// The system accent, the fallback of an unparseable colour.
    let accent: [CGFloat]
    /// The UI language `L()` resolves, live-switchable.
    let locale: String?

    @MainActor static var current: BarDrawEnvironment {
        BarDrawEnvironment(
            glass: LiquidGlassGate.drawsGlass,
            fonts: BarFont.generation,
            accent: NSColor.controlAccentColor
                .usingColorSpace(.sRGB)
                .map {
                    [$0.redComponent, $0.greenComponent, $0.blueComponent]
                }
                ?? [],
            locale: LocalizationManager.shared.effectiveLocale
        )
    }
}
