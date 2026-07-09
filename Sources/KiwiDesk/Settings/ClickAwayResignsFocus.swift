import AppKit
import SwiftUI

/// A transparent background layer that resigns the key window's
/// first responder on click (#93). Several settings fields
/// (`StepperRow`, `ColorSwatch`'s hex field, `SpaceNameField`)
/// use `@FocusState` and commit on focus loss — but on macOS,
/// clicking empty/non-focusable space does NOT resign a
/// `TextField`'s first responder the way it does on iOS, so a
/// typed value can stick uncommitted until Return or clicking
/// another field.
///
/// Meant to sit BEHIND real content in a `ZStack`, never as a
/// gesture on the whole container: SwiftUI hit-tests top-down,
/// so any actual control (button, picker, field) drawn on top
/// still claims its own click first, and only genuinely empty
/// area falls through to this layer's tap. `Color.clear` still
/// participates in hit-testing via `.contentShape`, so it needs
/// no visible fill to catch the click.
struct ClickAwayResignsFocus: View {
    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
            .accessibilityHidden(true)
    }
}
