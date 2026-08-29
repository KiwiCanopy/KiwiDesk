import Foundation

/// Command execution: the single entry point shared by the
/// Lua API, the CLI, and the IPC socket. Split from the
/// dispatch switch at the file ceiling.
extension KiwiCore {
    @discardableResult
    public func execute(
        _ command: String,
        args: [JSONValue] = []
    ) -> CommandResponse {
        let response = dispatchCommand(command, args: args)
        // Every command run inside a hotkey fire is tallied so
        // the hold-to-glide engine can decide eligibility from
        // what the press actually DID (#1056) — a binding's
        // body is opaque Lua, so this is the one honest signal.
        // The passthrough drops it outside a fire. This wrapper
        // is `dispatchCommand`'s ONE caller
        // (`HoldGlideEligibilitySeamTests`): a second dispatch entry
        // would run commands the tally never sees.
        keys.noteCommand(
            command,
            args: args,
            succeeded: response.isSuccess
        )
        return response
    }
}
