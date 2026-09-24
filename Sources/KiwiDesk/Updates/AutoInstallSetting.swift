import Combine
import Foundation

/// "Install updates automatically" as the Settings row sees it
/// (#1542): Sparkle's own value, observed rather than copied, and
/// whether Sparkle will take it at all.
@MainActor
final class AutoInstallSetting: ObservableObject {
    /// Why the switch cannot be turned on.
    enum Unavailable: Equatable {
        /// No update channel: an unbundled run.
        case noChannel
        /// Sparkle refuses it while automatic checks are off.
        case checksOff
    }

    @Published private(set) var isOn: Bool
    @Published private(set) var unavailable: Unavailable?

    private let read: () -> (isOn: Bool, unavailable: Unavailable?)
    private let write: (Bool) -> Void
    private var watch: AnyCancellable?

    /// `changes` fires whenever Sparkle's value may have moved —
    /// its KVO, which also sees an outside `defaults write`.
    init(
        read: @escaping () -> (isOn: Bool, unavailable: Unavailable?),
        write: @escaping (Bool) -> Void,
        changes: AnyPublisher<Void, Never> = Empty().eraseToAnyPublisher()
    ) {
        self.read = read
        self.write = write
        let now = read()
        isOn = now.isOn
        unavailable = now.unavailable
        watch = changes.sink { [weak self] in self?.refresh() }
    }

    /// The inert channel's: off, and why.
    static func inert() -> AutoInstallSetting {
        AutoInstallSetting(
            read: { (false, .noChannel) },
            write: { _ in }
        )
    }

    /// Writes through, then reads back what Sparkle kept.
    func set(_ on: Bool) {
        guard unavailable == nil else { return }
        write(on)
        refresh()
    }

    func refresh() {
        let now = read()
        isOn = now.isOn
        unavailable = now.unavailable
    }
}
