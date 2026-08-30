import SwiftUI

/// Scroll-to and flash timing for search reveal highlights (#277).
enum SettingsReveal {
    static let peakOpacity = 0.18
    static let cornerRadius: CGFloat = 6
    static let bleed: CGFloat = 4
    static let scroll = 0.3
    static let settle = 0.1
    static let hold = 0.3
    static let fade = 0.9

    static func nanoseconds(_ seconds: Double) -> UInt64 {
        UInt64(seconds * 1_000_000_000)
    }
}

/// Active flash target: anchor id plus token to re-fire identical anchors.
struct SettingsFlash: Equatable {
    let anchor: String
    let token: Int
}

private struct SettingsFlashKey: EnvironmentKey {
    static let defaultValue: SettingsFlash? = nil
}

private struct SettingsRevealTargetKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    /// Flash in progress keyed by anchor id (`SettingsControl.id`).
    var settingsFlash: SettingsFlash? {
        get { self[SettingsFlashKey.self] }
        set { self[SettingsFlashKey.self] = newValue }
    }

    /// Anchor id targeted by in-flight reveal request.
    var settingsRevealTarget: String? {
        get { self[SettingsRevealTargetKey.self] }
        set { self[SettingsRevealTargetKey.self] = newValue }
    }
}

/// Hoisted inline drawer scroll ids collected at section top (#610).
struct HoistedRevealAnchorsKey: PreferenceKey {
    static let defaultValue: [SettingsControl] = []
    static func reduce(
        value: inout [SettingsControl],
        nextValue: () -> [SettingsControl]
    ) {
        value.append(contentsOf: nextValue())
    }
}

/// Paints reveal wash behind anchored content.
private struct SearchRevealFlash: ViewModifier {
    let anchor: String
    @Environment(\.settingsFlash) private var flash
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    private var isMine: Bool { flash?.anchor == anchor }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(
                    cornerRadius: SettingsReveal.cornerRadius
                )
                .fill(
                    SettingsTheme.accent.opacity(
                        isMine ? SettingsReveal.peakOpacity : 0
                    )
                )
                .padding(-SettingsReveal.bleed)
            }
            .animation(fadeOut, value: isMine)
    }

    private var fadeOut: Animation? {
        guard !reduceMotion, !isMine else { return nil }
        return .easeOut(duration: SettingsReveal.fade)
    }
}

// MARK: - The raw halves (#573)

extension View {
    fileprivate func searchAnchor(
        _ anchor: String
    ) -> some View {
        id(anchor)
    }

    fileprivate func searchFlash(
        _ anchor: String
    ) -> some View {
        modifier(SearchRevealFlash(anchor: anchor))
    }
}

// MARK: - The typed surface

extension View {
    /// Anchors and flashes a self-contained settings control.
    func searchAnchored(
        _ control: SettingsControl
    ) -> some View {
        self.searchFlash(control.id).searchAnchor(control.id)
    }

    /// Sets scroll target on outer container card.
    /// Pairs with `searchFlashHeader`.
    func searchAnchorCard(
        _ control: SettingsControl
    ) -> some View {
        searchAnchor(control.id)
    }

    /// Flashes header of container card. Pairs with `searchAnchorCard`.
    func searchFlashHeader(
        _ control: SettingsControl
    ) -> some View {
        searchFlash(control.id)
    }

    /// Hoisted scroll target marker at section top
    /// (`SettingsAnchorPrimitiveTests`, #610).
    func searchScrollAnchor(
        _ control: SettingsControl
    ) -> some View {
        searchAnchor(control.id)
    }
}
