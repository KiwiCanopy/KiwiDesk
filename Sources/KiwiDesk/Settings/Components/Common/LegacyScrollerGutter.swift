import AppKit
import SwiftUI

/// Reports the trailing room a vertical `ScrollView`'s content holds
/// so it lays out at one width whether it scrolls or fits (#3491):
/// a legacy scroller's width while the content fits, nothing
/// otherwise. An overlay scroller takes no width, and a legacy one
/// that shows takes its own; the content pads itself by the room,
/// since a scroll view's own margins do not narrow it (measured on
/// macOS 27, 2026-11-19). Content that grows past the fit under
/// the room loses it to the scroller, which takes the same width.
struct LegacyScrollerGutter: ViewModifier {
    @Binding var room: CGFloat
    @State private var legacy = Self.legacyNow
    #if DEBUG
        @Environment(\.legacyScrollerForced) private var forced
    #endif
    @State private var container: CGFloat = 0
    @State private var content: CGFloat = 0

    func body(content view: Content) -> some View {
        view
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { container = geometry.size.height }
                        .onChange(of: geometry.size.height) { _, height in
                            container = height
                        }
                }
            }
            .onPreferenceChange(ScrollContentHeight.self) { height in
                content = height
            }
            .onChange(of: container) { update() }
            .onChange(of: content) { update() }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSScroller.preferredScrollerStyleDidChangeNotification
                )
            ) { _ in
                legacy = Self.legacyNow
                update()
            }
            .onAppear(perform: update)
    }

    private func update() {
        let fits = content > 0 && content <= container
        room = isLegacy && fits ? Self.width : 0
    }

    private var isLegacy: Bool {
        #if DEBUG
            if forced { return true }
        #endif
        return legacy
    }

    private static var legacyNow: Bool {
        NSScroller.preferredScrollerStyle == .legacy
    }

    /// The width a showing legacy scroller takes from its content.
    static var width: CGFloat {
        NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    }
}

/// The scroll content's height, as `reportsScrollContentHeight`
/// measures it.
private struct ScrollContentHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#if DEBUG
    private struct LegacyScrollerForcedKey: EnvironmentKey {
        static let defaultValue = false
    }

    extension EnvironmentValues {
        /// Treats the scroller as legacy whatever macOS prefers, for
        /// a test: `NSScroller` caches its preferred style for the
        /// process once anything has read it.
        var legacyScrollerForced: Bool {
            get { self[LegacyScrollerForcedKey.self] }
            set { self[LegacyScrollerForcedKey.self] = newValue }
        }
    }
#endif

extension View {
    /// Writes into `room` the trailing room this vertical
    /// `ScrollView`'s content pads itself by; its content reports
    /// its height through `reportsScrollContentHeight()`.
    func legacyScrollerGutter(_ room: Binding<CGFloat>) -> some View {
        modifier(LegacyScrollerGutter(room: room))
    }

    /// Reports this scroll content's height to the
    /// `legacyScrollerGutter` around its `ScrollView`.
    func reportsScrollContentHeight() -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollContentHeight.self,
                    value: geometry.size.height
                )
            }
        }
    }
}
