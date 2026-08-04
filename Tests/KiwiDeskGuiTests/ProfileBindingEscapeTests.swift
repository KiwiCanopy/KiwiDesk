import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Desktop bindings' escape hatch (#678 turn 13a).
///
/// While displays have separate Spaces the binding rows are
/// greyed — and the runtime keeps firing a binding made BEFORE
/// that setting changed, because `applyNativeSpaceBinding`
/// consults no display-Spaces state. These rows are the only
/// place a binding can be cleared, so without a way out the grey
/// would strand a binding that loads forever and cannot be
/// removed short of a log out. That is the failure this suite
/// exists for; guard-prover found the button unguarded at every
/// altitude, with its whole `if` block deletable green.
///
/// The presence rule's other half — that the button is ABSENT
/// rather than dimmed with nothing to clear — is
/// `GreyOutHidingTests`, whose `hidingExempt` entry states why.
@Suite("Profile binding escape hatch")
@MainActor
struct ProfileBindingEscapeTests {
    private func model() -> SettingsModel {
        SettingsModel(core: makeTestCore())
    }

    @Test("clearing removes every binding")
    func clearsEveryBinding() {
        let model = model()
        model.config.profileBindings = [1: "Desk", 3: "Laptop"]
        model.clearProfileBindings()
        #expect(model.config.profileBindings.isEmpty)
    }

    /// Staged, not written through — the footer's Save owns the
    /// write, like every other binding edit, so a mis-click on a
    /// destructive verb stays revertible.
    ///
    /// The binding is seeded into the CLEAN baseline first, so
    /// the fixture models a binding that was loaded from disk.
    /// Setting it on `config` alone and then clearing would land
    /// back on the baseline and read clean — a green that says
    /// nothing.
    @Test("clearing stages the edit rather than saving it")
    func clearingIsStaged() {
        let model = model()
        model.config.profileBindings = [1: "Desk"]
        model.cleanConfig = model.config
        model.recomputeDirty()
        #expect(!model.isDirty)
        model.clearProfileBindings()
        #expect(model.isDirty)
    }

    /// The button the greyed card offers must call THAT verb,
    /// not re-implement it inline where no test can reach it.
    /// Both halves matter: the call, and the presence condition
    /// that keeps it out of a card with nothing to clear.
    @Test("the greyed card offers the escape hatch")
    func theCardOffersIt() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/"
                            + "Profiles/NativeSpacesGroup.swift"
                    ),
                encoding: .utf8
            )
        )
        let squashed = source.split(
            whereSeparator: \.isWhitespace
        ).joined()
        #expect(
            squashed.contains("model.clearProfileBindings()"),
            Comment(
                rawValue:
                    "the bindings card no longer offers "
                    + "`clearProfileBindings` — a greyed row set "
                    + "with no way to clear a binding is the trap "
                    + "the grey exists to prevent"
            )
        )
        #expect(
            squashed.contains(
                "native_spaces.clear_all"
            ),
            Comment(
                rawValue:
                    "the escape hatch lost its label — it is "
                    + "reachable only from this card"
            )
        )
        #expect(
            squashed.contains(
                "if!model.config.profileBindings.isEmpty{"
            ),
            Comment(
                rawValue:
                    "the escape hatch lost its presence "
                    + "condition — it must be absent, not "
                    + "dimmed, with nothing to clear"
            )
        )
    }
}
