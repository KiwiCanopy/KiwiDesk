import Foundation

/// The app verbs take a bundle id and resolve nothing by name
/// (#2222): a refusal for an argument that is a running app's
/// name says which id would have worked, the shape the CLI's
/// unknown-command did-you-mean takes. English, as every CLI/IPC
/// error is.
extension KiwiCore {
    /// `response`, with the bundle id of the running app `args`
    /// names appended to a refusal; anything else unchanged.
    func namingBundleID(
        _ response: CommandResponse,
        _ args: [JSONValue]
    ) -> CommandResponse {
        // A dot reads as a bundle id already, and spares the
        // running-app walk the refusals a key press can hit.
        guard let error = response.error,
            let name = args.first?.stringValue, !name.contains("."),
            let id = openOrFocus.bundleIDNamed(name)
        else { return response }
        return .fail("\(error) — did you mean '\(id)'?")
    }
}
