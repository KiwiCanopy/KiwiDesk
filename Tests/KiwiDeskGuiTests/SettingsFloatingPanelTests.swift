import Foundation
import Testing

@testable import KiwiDesk

/// The detached preview card's geometry (#678 turn 17a).
///
/// The card is the one thing in this pass the user can put
/// somewhere, which is the one thing that can be put somewhere
/// unreachable: dragged past an edge on a 720 pt window there
/// is no scrollbar, no menu and no shortcut that brings it
/// back — only a resize the user has no reason to connect to
/// it. So the clamp is arithmetic rather than a gesture bound,
/// and this suite asserts it lands whole inside the content
/// area from every direction.
@Suite("Floating preview geometry")
struct SettingsFloatingPanelTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )

    /// The narrowest window the shell allows, less nothing:
    /// the card floats over the CONTENT area, which at the
    /// minimum is the whole width and the height under the
    /// header.
    private let minimumBounds = CGSize(
        width: SettingsWidthClass.minimum,
        height: 460
    )
    private let roomyBounds = CGSize(width: 1100, height: 800)

    @Test("the card rests inside the trailing top corner")
    func restsInTheCorner() {
        for bounds in [minimumBounds, roomyBounds] {
            let origin = SettingsFloatingPanel.origin(in: bounds)
            #expect(origin.y == SettingsFloatingPanel.inset)
            #expect(
                origin.x + SettingsTheme.panelWidth
                    + SettingsFloatingPanel.inset == bounds.width
            )
            // And it fits at all — the panel column plus two
            // gutters inside the hard minimum, which is what
            // makes a floating card a legitimate answer at
            // that width rather than a cover for it.
            #expect(origin.x >= SettingsFloatingPanel.inset)
        }
    }

    @Test("the card never leaves the content area")
    func travelStaysInside() {
        for bounds in [minimumBounds, roomyBounds] {
            let origin = SettingsFloatingPanel.origin(in: bounds)
            let height = SettingsFloatingPanel.height(in: bounds)
            // Push it hard in every direction, well past what
            // a real drag would reach.
            let far: CGFloat = 5000
            for proposed in [
                CGSize(width: -far, height: -far),
                CGSize(width: far, height: far),
                CGSize(width: -far, height: far),
                CGSize(width: far, height: -far),
            ] {
                let landed = SettingsFloatingPanel.clamp(
                    proposed,
                    in: bounds
                )
                let frame = CGRect(
                    x: origin.x + landed.width,
                    y: origin.y + landed.height,
                    width: SettingsTheme.panelWidth,
                    height: height
                )
                #expect(frame.minX >= SettingsFloatingPanel.inset)
                #expect(frame.minY >= SettingsFloatingPanel.inset)
                #expect(
                    frame.maxX
                        <= bounds.width
                        - SettingsFloatingPanel.inset
                )
                #expect(
                    frame.maxY
                        <= bounds.height
                        - SettingsFloatingPanel.inset
                )
            }
        }
    }

    /// A travel the card CAN make survives the clamp
    /// untouched. Without this the suite above passes on a
    /// clamp that pins the card to its corner and calls the
    /// drag a feature.
    @Test("a legal drag is not clamped")
    func legalDragSurvives() {
        let moved = CGSize(width: -120, height: 60)
        #expect(
            SettingsFloatingPanel.clamp(moved, in: roomyBounds)
                == moved
        )
    }

    /// The grip and the close button are TWO accessibility
    /// elements, each with its own name. Re-hoisting the label
    /// onto the row that contains the button is the exact
    /// regression the localization lane found and this pass
    /// fixed — and it takes `panel.hide_preview`'s only
    /// rendering site with it while the suite, `extract-keys`
    /// and every content guard stay green, because both keys
    /// are still present in every catalog and both still
    /// render *somewhere*. Matched on the modifier's SHAPE, per
    /// `AppRulesCensusRenderTests`' lesson: an earlier cut
    /// elsewhere accepted any mention of a key and went green
    /// when the modifier became a `.help()`.
    @Test("the grip and the close button are named apart")
    func namedApart() throws {
        let source = try squashed(
            "Sources/KiwiDesk/Settings/SettingsFloatingPanel.swift"
        )
        // The grip: its own element, its own label, and the
        // gesture on the same view.
        #expect(
            source.contains(
                ".accessibilityElement().accessibilityLabel("
                    + "L(\"panel.move_preview\","
            )
        )
        // The button names itself through the affordance, which
        // is what applies both `.help` and the label.
        #expect(
            source.contains(
                ".iconButtonAffordance(L(\"panel.hide_preview\","
            )
        )
        // And the row holding them both names nothing — the
        // container label is the defect, so its absence is the
        // assertion.
        #expect(
            !source.contains(
                "}.padding(.horizontal,12).padding(.top,8)"
                    + ".padding(.bottom,2).accessibilityLabel("
            )
        )
    }

    /// A window shorter than the card's ceiling gives the card
    /// the height it has, floored so a very short window still
    /// leaves something to read rather than a sliver.
    @Test("the card's height yields to a short window")
    func heightYields() {
        #expect(
            SettingsFloatingPanel.height(in: roomyBounds)
                == SettingsFloatingPanel.maxHeight
        )
        let short = CGSize(width: 900, height: 300)
        #expect(
            SettingsFloatingPanel.height(in: short)
                < SettingsFloatingPanel.maxHeight
        )
        #expect(SettingsFloatingPanel.height(in: short) >= 200)
        // The floor can exceed the window, which is deliberate
        // — a 200 pt card overhanging a 240 pt content area is
        // still a card, and the alternative is a preview with
        // no rows in it. The clamp above keeps its TOP corner
        // reachable regardless.
        #expect(
            SettingsFloatingPanel.clamp(
                .zero,
                in: CGSize(width: 900, height: 200)
            ) == .zero
        )
    }

    private func squashed(_ path: String) throws -> String {
        let url = Self.root.appendingPathComponent(path)
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .filter { !$0.isWhitespace }
    }
}
