import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// A tour page's content takes the spare height before its footer,
/// whose bottom pin otherwise split it in half and left the Spaces
/// step's list about one and a half rows tall (#3375).
///
/// Main-actor spend: two hosted pages laid out once each.
@Suite("A tour page's content takes the spare height (#3375)")
@MainActor
struct OnboardingPageRoomTests {
    /// The page's height inside the tour window, as
    /// `OnboardingBarsFitTests` derives it.
    private static let size = CGSize(
        width: OnboardingView.size.width - 2 * OnboardingView.inset.width,
        height: OnboardingView.size.height - 2 * OnboardingView.inset.height
    )

    private final class Box { var height: CGFloat = 0 }

    private func page(_ content: some View) -> some View {
        OnboardingPage(
            title: "Title",
            body1: "Body",
            back: {}
        ) {
            content
        } action: {
            Button("Continue") {}
        }
    }

    private func laidOut(_ view: some View) -> NSHostingView<AnyView> {
        let host = NSHostingView(
            rootView: AnyView(
                view.frame(width: Self.size.width)
                    .environmentObject(LocalizationManager.shared)
            )
        )
        host.frame = CGRect(origin: .zero, size: Self.size)
        host.layoutSubtreeIfNeeded()
        return host
    }

    @Test("a flexible content fills what the header and footer leave")
    func contentTakesTheRoom() {
        LocalizationManager.shared.select("en")
        let box = Box()
        let flexible = Color.clear
            .frame(maxHeight: .infinity)
            .onGeometryChange(for: CGFloat.self) {
                $0.size.height
            } action: {
                box.height = $0
            }
        _ = laidOut(page(flexible).frame(height: Self.size.height))
        // The page with nothing in it: header, footer and the two
        // stack gaps around the content.
        let bare = laidOut(page(Color.clear.frame(height: 0)))
            .fittingSize.height
        let spare = Self.size.height - bare
        #expect(spare > 200, "the fixture leaves room to split")
        #expect(box.height >= spare - 1, "content \(box.height) of \(spare)")
    }

    /// The list fades its edge for Current alone, the one option
    /// whose Spaces can outrun the page (#3375); a preset draws its
    /// rows unfaded.
    @Test("the Spaces list fades for Current alone")
    func fadeIsCurrentsAlone() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let source = try SourceScan.strippedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/Onboarding/OnboardingView+Spaces.swift"
            )
        )
        .split(whereSeparator: \.isWhitespace).joined()
        #expect(source.contains(".moreBelowFade(start.selected==.current)"))
        #expect(!source.contains(".moreBelowFade()"))
    }
}
