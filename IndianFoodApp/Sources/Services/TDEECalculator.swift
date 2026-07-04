import Foundation

// MARK: - TDEE Calculator (pure, no side effects)

enum TDEECalculator {

    // MARK: - BMR / TDEE / Daily Goal

    /// Mifflin-St Jeor BMR
    /// Male:   10×weight(kg) + 6.25×height(cm) − 5×age + 5
    /// Female: 10×weight(kg) + 6.25×height(cm) − 5×age − 161
    static func calculateBMR(profile: UserProfile) -> Double {
        let base = 10 * profile.weightKG
                 + 6.25 * profile.heightCM
                 - 5 * Double(profile.age)
        switch profile.biologicalSex {
        case .male:   return base + 5
        case .female: return base - 161
        }
    }

    /// TDEE = BMR × activity multiplier
    static func calculateTDEE(profile: UserProfile) -> Double {
        calculateBMR(profile: profile) * profile.activityLevel.multiplier
    }

    /// Daily calorie goal = TDEE + adjustment, floored at 1200 kcal
    static func calculateDailyGoal(profile: UserProfile) -> Int {
        let raw = calculateTDEE(profile: profile) + Double(profile.calorieAdjustment)
        return max(1200, Int(raw.rounded()))
    }

    // MARK: - Macro Goals (protein-per-kg + fat-floor, remaining to carbs)

    /// Protein target g.
    /// Cut = 2.2 g/kg (muscle-sparing), Maintain = 1.6 g/kg, Bulk = 1.8 g/kg.
    static func calculateProteinGoal(profile: UserProfile) -> Double {
        clampedMacros(profile: profile).proteinG
    }

    /// Fat target g — 25 % of daily goal calories ÷ 9 kcal/g.
    static func calculateFatGoal(profile: UserProfile) -> Double {
        clampedMacros(profile: profile).fatG
    }

    /// Carb target g — remaining calories after protein + fat, ÷ 4 kcal/g (≥ 0).
    static func calculateCarbGoal(profile: UserProfile) -> Double {
        clampedMacros(profile: profile).carbG
    }

    // MARK: - Private helper

    /// Single computation to avoid repeating the clamp logic across three public funcs.
    private static func clampedMacros(
        profile: UserProfile
    ) -> (proteinG: Double, fatG: Double, carbG: Double) {
        let dailyKcal = Double(calculateDailyGoal(profile: profile))

        // Per-kg multiplier by goal
        let proteinPerKg: Double
        switch profile.goalType {
        case .cut:      proteinPerKg = 2.2
        case .maintain: proteinPerKg = 1.6
        case .bulk:     proteinPerKg = 1.8
        }

        let rawProteinG = profile.weightKG * proteinPerKg
        let rawFatG     = dailyKcal * 0.25 / 9.0

        let proteinKcal = rawProteinG * 4
        let fatKcal     = rawFatG     * 9

        // Safety clamp: if protein+fat already uses all calories, scale both down
        if proteinKcal + fatKcal >= dailyKcal {
            let scale   = dailyKcal / (proteinKcal + fatKcal)
            return (
                proteinG: (rawProteinG * scale).rounded(toPlaces: 1),
                fatG:     (rawFatG     * scale).rounded(toPlaces: 1),
                carbG:    0
            )
        }

        let remainingKcal = dailyKcal - proteinKcal - fatKcal
        let carbG         = (remainingKcal / 4).rounded(toPlaces: 1)

        return (
            proteinG: rawProteinG.rounded(toPlaces: 1),
            fatG:     rawFatG.rounded(toPlaces: 1),
            carbG:    carbG
        )
    }
}

// MARK: - Double rounding helper

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
