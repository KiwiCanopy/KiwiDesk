import AppKit
import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The tour's login checkbox greys on a copy that cannot be a
/// login item and says why in Settings' words (#2094). The refusal
/// arrives through `loginItemUnavailable`, never a bundle URL.
@Suite("Onboarding login checkbox greys on an unstable copy")
@MainActor
struct OnboardingLoginGateTests {
    @Test(
        "a refused copy unticks and takes the Settings sentence",
        arguments: [LoginItemUnavailable.translocated, .notBundled]
    )
    func refusedCopyGreys(cause: LoginItemUnavailable) {
        LocalizationManager.shared.select("en")
        let model = OnboardingModel()
        model.loginItemUnavailable = cause
        #expect(!model.openAtLogin)
        #expect(
            model.loginItemReason
                == GeneralGateHelp.sentence(for: .cannotRegister(cause))
        )
    }

    @Test("a registerable copy stays ticked and live")
    func registerableCopyStaysLive() {
        let model = OnboardingModel()
        model.loginItemUnavailable = nil
        #expect(model.openAtLogin)
        #expect(model.loginItemReason == nil)
    }

    /// The caption is drawn: a refused copy's checkbox is taller.
    @Test("the hosted checkbox draws the reason only when refused")
    func hostedCheckboxCaptions() {
        LocalizationManager.shared.select("en")
        #expect(Self.height(.translocated) > Self.height(nil))
    }

    /// The dim and the caption read the ONE reason, and the closing
    /// card draws this checkbox. Headless AppKit lists no SwiftUI
    /// accessibility children, so the dim is pinned by shape.
    @Test("the dim and the caption read the one reason")
    func dimAndCaptionShareTheReason() throws {
        let source = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Onboarding/"
                        + "OnboardingView+Closing.swift"
                )
        )
        let flat = source.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
        for needle in [
            ".disabled(model.loginItemReason!=nil)",
            "ifletreason=model.loginItemReason{Text(reason)",
            "OnboardingLoginCheckbox(model:model).onboardingCard()",
        ] {
            #expect(flat.occurrences(of: needle) == 1, "\(needle)")
        }
    }

    private static func height(
        _ cause: LoginItemUnavailable?
    ) -> CGFloat {
        let model = OnboardingModel()
        model.loginItemUnavailable = cause
        return NSHostingView(
            rootView: OnboardingLoginCheckbox(model: model)
                .frame(width: 360)
        ).fittingSize.height
    }
}
