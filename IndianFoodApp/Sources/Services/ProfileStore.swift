import Foundation
import Combine

// MARK: - ProfileStore

final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    @Published var profile: UserProfile? {
        didSet { persist() }
    }

    private let defaultsKey = "userProfile"

    init() {
        load()
    }

    // MARK: - Public API

    func save(_ newProfile: UserProfile) {
        profile = newProfile
    }

    func clear() {
        profile = nil
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    /// Applies or clears a MacroOverride on the current profile, then persists.
    /// No-op if no profile is set.
    func setMacroOverride(_ override: MacroOverride?) {
        guard var p = profile else { return }
        p.macroOverride = override
        profile = p       // triggers didSet → persist()
    }

    // MARK: - Dietary preferences

    /// Empty set when no profile is set or no preferences chosen.
    var dietaryPreferences: Set<DietaryFilter> {
        profile?.dietaryPreferences ?? []
    }

    // MARK: - Computed goals

    /// Returns the TDEE-based daily goal if a profile exists, else 2000 (legacy default).
    var dailyCalorieGoal: Int {
        guard let profile else { return 2000 }
        return TDEECalculator.calculateDailyGoal(profile: profile)
    }

    var dailyProteinGoal: Double {
        guard let profile else { return 150 }
        if let ov = profile.macroOverride { return ov.proteinG }
        return TDEECalculator.calculateProteinGoal(profile: profile)
    }

    var dailyCarbsGoal: Double {
        guard let profile else { return 250 }
        if let ov = profile.macroOverride { return ov.carbsG }
        return TDEECalculator.calculateCarbGoal(profile: profile)
    }

    var dailyFatGoal: Double {
        guard let profile else { return 65 }
        if let ov = profile.macroOverride { return ov.fatG }
        return TDEECalculator.calculateFatGoal(profile: profile)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return }
        profile = decoded
    }

    private func persist() {
        guard let profile,
              let data = try? JSONEncoder().encode(profile)
        else {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            return
        }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
