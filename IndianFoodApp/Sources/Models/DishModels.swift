import Foundation

// MARK: - Classification

struct ClassificationResult {
    let className: String
    let confidence: Float
    let topCandidates: [(String, Float)]
}

// MARK: - Dish

struct DishMatch: Codable {
    let foodCode: String
    let foodName: String
    let energyKcalPerServing: Double?
    let proteinGPerServing: Double?
    let fatGPerServing: Double?
    let carbGPerServing: Double?
    let fibreGPerServing: Double?
    let hasGheeInBase: Int
    let hasButterInBase: Int
    let hasCreamInBase: Int
    let dairyFatAlreadyCounted: Int
    let foodCategory: String?
    let servingSizeG: Double?

    enum CodingKeys: String, CodingKey {
        case foodCode                  = "food_code"
        case foodName                  = "food_name"
        case energyKcalPerServing      = "energy_kcal_per_serving"
        case proteinGPerServing        = "protein_g_per_serving"
        case fatGPerServing            = "fat_g_per_serving"
        case carbGPerServing           = "carb_g_per_serving"
        case fibreGPerServing          = "fibre_g_per_serving"
        case hasGheeInBase             = "has_ghee_in_base"
        case hasButterInBase           = "has_butter_in_base"
        case hasCreamInBase            = "has_cream_in_base"
        case dairyFatAlreadyCounted    = "dairy_fat_already_counted"
        case foodCategory              = "food_category"
        case servingSizeG              = "serving_size_g"
    }
}

// MARK: - QA Flow

struct QAQuestion: Identifiable {
    let id: String
    let question: String
    let options: [QAOption]
    let required: Bool
    let affects: String
    var allowsManualWeight: Bool = false
}

struct QAOption: Identifiable {
    let id: String
    let value: String
    let label: String
    let hint: String
}

struct QAAnswers: Codable {
    var portionSize: String   = "standard"
    var riceAmount: String?   = nil
    var meatAmount: String?   = nil
    var cookingContext: String = "home"
    var gravyType: String     = "medium"
    var cookingMethod: String? = nil
    var flatAdditions: [String] = []
    var questionsSkipped: Int = 0
    var manualWeightG: Double? = nil

    enum CodingKeys: String, CodingKey {
        case portionSize       = "portion_size"
        case riceAmount        = "rice_amount"
        case meatAmount        = "meat_amount"
        case cookingContext    = "cooking_context"
        case gravyType         = "gravy_type"
        case cookingMethod     = "cooking_method"
        case flatAdditions     = "flat_additions"
        case questionsSkipped  = "questions_skipped"
        case manualWeightG     = "manual_weight_g"
    }
}

// MARK: - Macro Result

struct MacroResult: Codable {
    let kcalEstimate: Double
    let kcalLow: Double
    let kcalHigh: Double
    let proteinG: Double
    let fatG: Double
    let carbG: Double
    let fibreG: Double
    let confidenceBandPct: Double
    let questionsSkipped: Int
    let adjustmentsApplied: [String]

    enum CodingKeys: String, CodingKey {
        case kcalEstimate       = "kcal_estimate"
        case kcalLow            = "kcal_low"
        case kcalHigh           = "kcal_high"
        case proteinG           = "protein_g"
        case fatG               = "fat_g"
        case carbG              = "carb_g"
        case fibreG             = "fibre_g"
        case confidenceBandPct  = "confidence_band_pct"
        case questionsSkipped   = "questions_skipped"
        case adjustmentsApplied = "adjustments_applied"
    }
}

// MARK: - Class Map

struct ClassMap: Codable {
    let numClasses: Int
    let classes: [String: ClassMapEntry]

    enum CodingKeys: String, CodingKey {
        case numClasses = "num_classes"
        case classes
    }
}

struct ClassMapEntry: Codable {
    let classIdx: Int
    let indbFoodCode: String?
    let indbFoodName: String?
    let needsManualMapping: Bool
    let fallback: String?

    enum CodingKeys: String, CodingKey {
        case classIdx          = "class_idx"
        case indbFoodCode      = "indb_food_code"
        case indbFoodName      = "indb_food_name"
        case needsManualMapping = "needs_manual_mapping"
        case fallback
    }
}

// MARK: - Search / Browse

struct SearchResult: Codable, Identifiable {
    var id: String { foodCode }
    let foodCode: String
    let foodName: String
    let energyKcalPerServing: Double?
    let matchType: String
    let matchScore: Int
    let foodCategory: String?

    enum CodingKeys: String, CodingKey {
        case foodCode             = "food_code"
        case foodName             = "food_name"
        case energyKcalPerServing = "energy_kcal_per_serving"
        case matchType            = "match_type"
        case matchScore           = "match_score"
        case foodCategory         = "food_category"
    }
}

struct SearchResponse: Codable {
    let query: String
    let results: [SearchResult]
    let total: Int
}

struct BrowseCategory: Codable {
    let foodCode: String
    let foodName: String
    let energyKcalPerServing: Double?

    enum CodingKeys: String, CodingKey {
        case foodCode             = "food_code"
        case foodName             = "food_name"
        case energyKcalPerServing = "energy_kcal_per_serving"
    }
}

struct BrowseResponse: Codable {
    let categories: [String: [BrowseCategory]]
}

