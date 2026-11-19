import AppKit
import SwiftUI

/// Writes into `bound` the widest a vertical `ScrollView`'s content
/// may lay out: under a legacy scroller, the scroll view's width less
/// the scroller's, whether or not the content scrolls; nil under an
/// overlay scroller. A page whose segments swap in place then keeps
/// one width, so its columns hold still (#3491).
struct LegacyScrollerGutter: ViewModifier {
    @Binding var bound: CGFloat?
    @StateObject private var scroller = ScrollerStyleWatch()
    @State private var width: CGFloat = 0
    #if DEBUG
        @Environment(\.scrollerStyleForced) private var forced
    #endif

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { width = geometry.size.width }
                        .onChange(of: geometry.size.width) { _, now in
                            width = now
                        }
                }
            }
            .onChange(of: width) { update() }
            .onChange(of: scroller.style) { update() }
            .onAppear(perform: update)
    }

    private func update() {
        guard isLegacy, width > 0 else {
            bound = nil
            return
        }
        bound = width - Self.width
    }

    private var isLegacy: Bool {
        #if DEBUG
            if let forced { return forced == .legacy }
        #endif
        return scroller.style == .legacy
    }

    /// The width a showing legacy scroller takes from its content.
    static var width: CGFloat {
        NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    }
}

#if DEBUG
    private struct ScrollerStyleForcedKey: EnvironmentKey {
        static let defaultValue: NSScroller.Style? = nil
    }

    extension EnvironmentValues {
        /// The scroller style `LegacyScrollerGutter` bounds for,
        /// whatever macOS prefers, for a test: `NSScroller` caches its
        /// preferred style for the process once anything has read it.
        var scrollerStyleForced: NSScroller.Style? {
            get { self[ScrollerStyleForcedKey.self] }
            set { self[ScrollerStyleForcedKey.self] = newValue }
        }
    }
#endif

extension View {
    /// Writes into `bound` the widest this vertical `ScrollView`'s
    /// content may lay out (`LegacyScrollerGutter`).
    func legacyScrollerGutter(_ bound: Binding<CGFloat?>) -> some View {
        modifier(LegacyScrollerGutter(bound: bound))
    }
}
