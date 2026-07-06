import Foundation
import Combine

// MARK: - FastingModeStore

/// Persists the active Fasting Mode directly to UserDefaults, independent of
/// UserProfile/ProfileStore — it must survive relaunch (multi-day observance)
/// and work even when no profile has been set up.
final class FastingModeStore: ObservableObject {
    static let shared = FastingModeStore()

    @Published var mode: FastingMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: defaultsKey) }
    }

    private let defaultsKey = "fastingMode"

    init() {
        let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? FastingMode.none.rawValue
        mode = FastingMode(rawValue: raw) ?? .none
    }
}
