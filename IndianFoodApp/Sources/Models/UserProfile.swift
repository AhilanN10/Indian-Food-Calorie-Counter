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

// MARK: - DietaryFilter

/// Raw values match the backend's dietaryFilters query param tokens
/// and map to the is_* flag columns on the dishes table.
enum DietaryFilter: String, Codable, CaseIterable, Identifiable {
    case vegetarian    = "vegetarian"
    case vegan         = "vegan"
    case jain          = "jain"
    case noOnionGarlic = "no_onion_garlic"
    case glutenFree    = "gluten_free"
    case dairyFree     = "dairy_free"

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .vegetarian:    return "Vegetarian"
        case .vegan:         return "Vegan"
        case .jain:          return "Jain"
        case .noOnionGarlic: return "No Onion/Garlic"
        case .glutenFree:    return "Gluten-Free"
        case .dairyFree:     return "Dairy-Free"
        }
    }
}

// MARK: - FastingMode

/// Navratri/Ekadashi fasting-day filtering. Unlike DietaryFilter (per-session,
/// seeded from Profile but toggled freely in Search), this is a standing
/// multi-day observance persisted directly to UserDefaults by FastingModeStore
/// so it survives relaunch and applies everywhere immediately.
enum FastingMode: String, Codable, CaseIterable, Identifiable {
    case none     = "none"
    case navratri = "navratri"
    case ekadashi = "ekadashi"

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .none:     return "None"
        case .navratri: return "Navratri"
        case .ekadashi: return "Ekadashi"
        }
    }

    /// Query-param token sent to the backend; nil when no fasting mode is active.
    var queryParam: String? {
        self == .none ? nil : rawValue
    }
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
    var age:                Int
    var biologicalSex:      BiologicalSex
    var heightCM:           Double       // canonical: always stored in cm
    var weightKG:           Double       // canonical: always stored in kg
    var activityLevel:      ActivityLevel
    var goalType:           GoalType
    var calorieAdjustment:  Int          // 0 for maintain; negative for cut, positive for bulk
    var unitSystem:         UnitSystem
    var macroOverride:      MacroOverride?      // nil → use TDEECalculator values
    var dietaryPreferences: Set<DietaryFilter>  // empty = no dietary restrictions

    init(
        age:                Int,
        biologicalSex:      BiologicalSex,
        heightCM:           Double,
        weightKG:           Double,
        activityLevel:      ActivityLevel,
        goalType:           GoalType,
        calorieAdjustment:  Int,
        unitSystem:         UnitSystem,
        macroOverride:      MacroOverride? = nil,
        dietaryPreferences: Set<DietaryFilter> = []
    ) {
        self.age                = age
        self.biologicalSex      = biologicalSex
        self.heightCM           = heightCM
        self.weightKG           = weightKG
        self.activityLevel      = activityLevel
        self.goalType           = goalType
        self.calorieAdjustment  = calorieAdjustment
        self.unitSystem         = unitSystem
        self.macroOverride      = macroOverride
        self.dietaryPreferences = dietaryPreferences
    }

    // Custom decoder so profiles saved before dietaryPreferences existed
    // still decode instead of being silently discarded by ProfileStore.load()
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        age                = try c.decode(Int.self,           forKey: .age)
        biologicalSex      = try c.decode(BiologicalSex.self, forKey: .biologicalSex)
        heightCM           = try c.decode(Double.self,        forKey: .heightCM)
        weightKG           = try c.decode(Double.self,        forKey: .weightKG)
        activityLevel      = try c.decode(ActivityLevel.self, forKey: .activityLevel)
        goalType           = try c.decode(GoalType.self,      forKey: .goalType)
        calorieAdjustment  = try c.decode(Int.self,           forKey: .calorieAdjustment)
        unitSystem         = try c.decode(UnitSystem.self,    forKey: .unitSystem)
        macroOverride      = try c.decodeIfPresent(MacroOverride.self, forKey: .macroOverride)
        dietaryPreferences = try c.decodeIfPresent(Set<DietaryFilter>.self,
                                                   forKey: .dietaryPreferences) ?? []
    }

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
            unitSystem:        .metric
        )
    }
}
