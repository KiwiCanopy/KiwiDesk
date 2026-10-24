import Foundation

/// The GUI's hooks for the plate cues Core pays at once — the
/// layout cue (`payModeCue`) and the Space cue (`paySpaceCue`). The
/// Desktop cue's hook rides its own ledger
/// (`DesktopCueLedger.onCue`), since that cue is owed and paid
/// later. It also holds the Space Bar pick scope the Space cue's
/// payer reads (`fromSpaceBar`, #2591).
@MainActor
final class CueHooks {
    var onModeCue: @MainActor (ModeCycleCue) -> Void = { _ in }
    var onSpaceCue: @MainActor (SpaceSwitchCue) -> Void = { _ in }
    /// Set while a Space Bar pick runs (`fromSpaceBar`).
    var spaceBarPicking = false
}
