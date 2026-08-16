import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Spaces panel's chip row — which Space it shows, and who
/// gets to say (#794; review round, 2026-08-16).
///
/// Split from `SpacesPanelPreviewTests` at the §2.1 ceiling, and
/// they fail apart: that suite holds the caption's COUNT, this
/// one holds the selection. Both were added because the panel
/// answers about one Space and three things can name it — the
/// open override editor, the chip the reader picked, and the
/// draft's first Space.
@Suite("Spaces panel selection")
@MainActor
struct SpacesPanelSelectionTests {
    /// A chip drives the open override editor.
    ///
    /// `space` gives `nav.spaceOverridesFocus` precedence over
    /// the chip selection, so with the editor open a chip that
    /// only set `selected` moved nothing and gave no feedback —
    /// a fully live control that does nothing, which "grey,
    /// don't hide" exists to prevent (review round,
    /// 2026-08-16). The fix drives the editor instead of dimming
    /// the chip: the panel and the editor show ONE Space, and
    /// either may say which.
    ///
    /// It shipped with no test, so deleting the branch restored
    /// the defect with the whole suite green — a behaviour
    /// change owes a test that reds when it is reverted
    /// (`tests.md` ▸ Owed).
    @Test("a chip moves the Space the editor is showing")
    func chipDrivesTheOpenEditor() {
        let model = makeTestModel()
        model.config.spaces = ["1", "2", "3"]
        model.config.spaceModes = ["1": .bsp, "2": .grid]
        let view = SpacesPanelPreview(model: model)

        // Editor open on "1": the panel follows it, not the
        // chip's own default.
        model.nav.spaceOverridesFocus = "1"
        #expect(view.shownSpace == "1")

        // Picking "2" moves BOTH — the editor's focus and the
        // drawn Space. Without the fix the focus stays on "1"
        // and the picture never changes.
        view.pick("2")
        #expect(model.nav.spaceOverridesFocus == "2")
        #expect(view.shownSpace == "2")

        // With no editor open, a chip must not INVENT a focus —
        // opening the editor is a navigation the panel does not
        // perform, and setting the focus would push the reader
        // into an editor they did not ask for.
        model.nav.spaceOverridesFocus = nil
        view.pick("3")
        #expect(model.nav.spaceOverridesFocus == nil)
    }

    /// Stated limit of the test above: it cannot see the chip's
    /// OTHER half. `selected` is `@State`, whose storage is only
    /// live once the view is installed in a hierarchy, so a
    /// write from a bare struct goes nowhere a suite can read —
    /// `shownSpace` keeps answering the fallback. What is
    /// covered is the branch the review found broken (the chip
    /// driving an open editor) and the one it must not take
    /// (inventing a focus); the plain-selection path is reachable
    /// only on screen.

}
