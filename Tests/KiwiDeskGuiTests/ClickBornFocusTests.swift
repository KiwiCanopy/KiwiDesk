import Foundation
import Testing

@testable import KiwiDesk

/// The #1309 arm on `ClickBornFocus`, held at both its answers.
///
/// The defect it closes is not a stray ring but the opposite: a
/// refusal firing on a click the user aimed at a text field. A
/// container's `.focused($x)` reads "focus is within me", so the
/// Settings detail pane's binding turns true when a hex field
/// takes the caret — and the refusal answered by the button
/// state alone then cleared that field. Every failing click on
/// the device logged the same three lines in the same order:
/// the swatch focused, the pane refused, the swatch unfocused
/// (2026-09-07). Disabling only the refusal made every field
/// clickable on the same build, which is the causal half.
///
/// These pin the DECISION rather than the live read: the live
/// property needs an `NSApplication` and a key window, neither
/// of which a test host has. What holds the wiring between the
/// two is `refusalIsWiredToTheLiveRead` below — the function
/// being right buys nothing if the caller stops passing it.
@Suite("A click that starts text editing is not a stray ring")
struct ClickBornFocusTests {
    @Test("text editing withholds the refusal, however clicked")
    func editingNeverRefused() {
        for held in [true, false] {
            for dispatching in [true, false] {
                #expect(
                    ClickBornFocus.refuses(
                        mouseHeld: held,
                        dispatchingMouseEvent: dispatching,
                        textEditingOwnsFocus: true
                    ) == false
                )
            }
        }
    }

    /// The other value of the same argument, or the arm above
    /// would pass on a function that refuses nothing at all.
    @Test("either mouse reading alone still refuses")
    func mouseStillRefused() {
        #expect(
            ClickBornFocus.refuses(
                mouseHeld: true,
                dispatchingMouseEvent: false,
                textEditingOwnsFocus: false
            )
        )
        #expect(
            ClickBornFocus.refuses(
                mouseHeld: false,
                dispatchingMouseEvent: true,
                textEditingOwnsFocus: false
            )
        )
    }

    /// #991 allows programmatic focus, and the arrival ring
    /// (#996) is exactly that — the first line of the device log
    /// is `clickBorn=false pressed=0`, an allowed focus.
    @Test("a focus change with no mouse behind it stands")
    func programmaticFocusStands() {
        #expect(
            ClickBornFocus.refuses(
                mouseHeld: false,
                dispatchingMouseEvent: false,
                textEditingOwnsFocus: false
            ) == false
        )
    }

    /// The wiring, not the function. Gut the live property's
    /// third argument to a literal and every assertion above
    /// stays green while the defect returns whole — the class of
    /// no-op fix this repo has shipped twice (`tests.md`).
    @Test("the refusal is wired to the live text-editing read")
    func refusalIsWiredToTheLiveRead() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Common/"
                    + "ClickBornFocus.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        #expect(
            source.contains(
                "textEditingOwnsFocus:textEditingOwnsFocus"
            ),
            Comment(
                rawValue:
                    "`isClickBorn` no longer hands `refuses` the "
                    + "live editable-responder read, so the "
                    + "#1309 arm cannot fire however the pure "
                    + "function is written. Pass the property, "
                    + "never a literal."
            )
        )
    }
}
