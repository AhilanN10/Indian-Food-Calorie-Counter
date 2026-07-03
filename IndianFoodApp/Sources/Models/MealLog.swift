import Foundation
import SwiftData

// MARK: - MealLog model

@Model
class MealLog {
    var id: UUID
    var dishName: String
    var foodCode: String
    var kcalEstimate: Double
    var proteinG: Double
    var fatG: Double
    var carbG: Double
    var fibreG: Double
    var kcalLow: Double
    var kcalHigh: Double
    var mealType: String
    var loggedAt: Date
    var confidenceBandPct: Double
    var adjustmentsApplied: [String]

    init(
        dishName: String,
        foodCode: String,
        result: MacroResult,
        mealType: String
    ) {
        self.id                  = UUID()
        self.dishName            = dishName
        self.foodCode            = foodCode
        self.kcalEstimate        = result.kcalEstimate
        self.proteinG            = result.proteinG
        self.fatG                = result.fatG
        self.carbG               = result.carbG
        self.fibreG              = result.fibreG
        self.kcalLow             = result.kcalLow
        self.kcalHigh            = result.kcalHigh
        self.mealType            = mealType
        self.loggedAt            = Date()
        self.confidenceBandPct   = result.confidenceBandPct
        self.adjustmentsApplied  = result.adjustmentsApplied
    }
}

// MARK: - MealType

enum MealType: String, CaseIterable {
    case breakfast = "Breakfast"
    case lunch     = "Lunch"
    case dinner    = "Dinner"
    case snack     = "Snack"

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch:     return "sun.max.fill"
        case .dinner:    return "moon.stars.fill"
        case .snack:     return "leaf.fill"
        }
    }
}
