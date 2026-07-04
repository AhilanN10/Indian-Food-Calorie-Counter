import Foundation

// MARK: - Supporting Enums

enum BiologicalSex: String, Codable, CaseIterable {
    case male   = "Male"
    case female = "Female"
}

enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary  = "Sedentary"
    case light      = "Lightly Active"
    case moderate   = "Moderately Active"
    case active     = "Active"
    case veryActive = "Very Active"

    var multiplier: Double {
        switch self {
        case .sedentary:  return 1.2
        case .light:      return 1.375
        case .moderate:   return 1.55
        case .active:     return 1.725
        case .veryActive: return 1.9
        }
    }

    var shortLabel: String {
        switch self {
        case .sedentary:  return "Desk job, no exercise"
        case .light:      return "Light exercise 1–3×/week"
        case .moderate:   return "Moderate exercise 3–5×/week"
        case .active:     return "Hard exercise 6–7×/week"
        case .veryActive: return "Athlete / physical job"
        }
    }
}

enum GoalType: String, Codable, CaseIterable {
    case maintain = "Maintain"
    case cut      = "Cut"
    case bulk     = "Bulk"
}

enum UnitSystem: String, Codable, CaseIterable {
    case metric   = "Metric"
    case imperial = "Imperial"
}

// MARK: - MacroOverride

/// User-supplied custom macro targets. nil = use calculated values.
struct MacroOverride: Codable {
    var proteinG: Double
    var carbsG:   Double
    var fatG:     Double
}

// MARK: - UserProfile

struct UserProfile: Codable {
    var age:               Int
    var biologicalSex:     BiologicalSex
    var heightCM:          Double       // canonical: always stored in cm
    var weightKG:          Double       // canonical: always stored in kg
    var activityLevel:     ActivityLevel
    var goalType:          GoalType
    var calorieAdjustment: Int          // 0 for maintain; negative for cut, positive for bulk
    var unitSystem:        UnitSystem
    var macroOverride:     MacroOverride?   // nil → use TDEECalculator values

    // Default fully-configured profile
    static var `default`: UserProfile {
        UserProfile(
            age:               25,
            biologicalSex:     .male,
            heightCM:          175,
            weightKG:          70,
            activityLevel:     .moderate,
            goalType:          .maintain,
            calorieAdjustment: 0,
            unitSystem:        .metric,
            macroOverride:     nil
        )
    }
}
