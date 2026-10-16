import AppKit

/// The mask's cached WindowServer list (#2103 ruling 21): read at
/// a settle pass or where an event owed it, never per pass.
extension VisionManager {
    /// Re-reads the WindowServer list where `refresh` asks or
    /// nothing is cached, noting which windows `tracks` names.
    func listedWindows(
        refresh: Bool,
        tracks: (CGWindowID) -> Bool,
        radius: (CGWindowID) -> CGFloat,
        bundle: ((pid_t) -> String?)?
    ) -> [FloatDetection.ListedWindow] {
        if refresh || listed == nil {
            let read = listWindows()
            listed = read
            trackedAtRead = Set(read.map(\.number).filter(tracks))
            listedRadii = Dictionary(
                read
                    .filter {
                        $0.layer == 0
                            && !self.trackedAtRead.contains($0.number)
                    }
                    .map { ($0.number, radius($0.number)) },
                uniquingKeysWith: { first, _ in first }
            )
            var bundles: [pid_t: String?] = [:]
            if let bundle {
                let readable = read.filter {
                    $0.layer == 0
                        || KiwiCore.isBeneathNormal(layer: $0.layer)
                }
                for pid in Set(readable.map(\.pid)) {
                    bundles[pid] = listedBundles[pid] ?? bundle(pid)
                }
            }
            listedBundles = bundles
        }
        return listed ?? []
    }

    /// Moves a listed window to the bounds its own event reported
    /// (CG coordinates), or drops it where `frame` is nil — it
    /// hid or closed. True where the cache changed.
    func noteListedWindow(_ number: CGWindowID, frame: CGRect?) -> Bool {
        guard var all = listed,
            let index = all.firstIndex(where: { $0.number == number })
        else { return false }
        if let frame {
            guard all[index].frame != frame else { return false }
            let old = all[index]
            all[index] = FloatDetection.ListedWindow(
                number: old.number,
                pid: old.pid,
                layer: old.layer,
                frame: frame
            )
        } else {
            all.remove(at: index)
        }
        listed = all
        return true
    }

    /// Drops the cached list: no mask reads it.
    func forgetListedWindows() {
        listed = nil
        trackedAtRead = []
        listedRadii = [:]
        listedBundles = [:]
    }
}
