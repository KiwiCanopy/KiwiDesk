import Foundation

/// Taking over a leftover Hyper remap (#2471): a mapping another
/// tool set that is exactly KiwiDesk's own entry for the chosen
/// key becomes KiwiDesk's on the user's consent, for this boot.
extension KiwiCore {
    nonisolated public static let takeOverHyperRemapCommand =
        "take_over_hyper_remap"

    /// `take_over_hyper_remap`: CLI and Settings only (`cliOnly`),
    /// never `init.lua`, which would turn one consent into a
    /// standing rule. Answers as `set_hyper_key` does.
    @discardableResult
    public func takeOverHyperRemap() -> CommandResponse {
        guard let want = appWide.hyperKey else {
            return .fail("no Hyper key is chosen")
        }
        guard eventLoop.isRunning else {
            return .fail("Hyper waits until KiwiDesk manages windows")
        }
        deferred.cancel(.hyperRemap)
        setHyperState(HyperKeyRemap.claim(want, on: hyperRemapHost))
        if keys.hyperStatus == .on {
            onLog("hyper: took over the existing remap")
        }
        return hyperReply
    }
}
