import Foundation

class QuestionEngine: ObservableObject {

    /// Responses dict value prefix marking an exact-weight answer, e.g. "manual:150.0"
    static let manualWeightPrefix = "manual:"
    /// Responses dict value prefix marking a katori-count answer, e.g. "katori:1.5"
    static let katoriPrefix = "katori:"
    /// Responses dict value prefix marking a piece-count answer, e.g. "piece:2"
    static let piecePrefix = "piece:"

    // MARK: - Main entry point
    func generateQuestions(for dish: DishMatch?,
                           classificationResult: ClassificationResult?) -> [QAQuestion] {
        let category = dish?.foodCategory ?? "other"
        var questions: [QAQuestion] = []

        switch category {
        case "beverage":
            questions += beverageQuestions()
        case "bread":
            questions += breadQuestions(dish: dish)
        case "rice":
            questions += riceQuestions(dish: dish)
        case "dal_legume":
            questions += dalLegumeQuestions(dish: dish)
        case "meat_fish":
            questions += meatFishQuestions(dish: dish)
        case "vegetable":
            questions += vegetableQuestions(dish: dish)
        case "paneer_dairy":
            questions += paneerDairyQuestions(dish: dish)
        case "snack_street":
            questions += snackStreetQuestions(dish: dish)
        case "sweet_dessert":
            questions += sweetDessertQuestions(dish: dish)
        case "condiment_side":
            questions += condimentQuestions()
        default:
            questions += defaultQuestions(dish: dish)
        }

        return questions
    }

    // MARK: - Beverage
    private func beverageQuestions() -> [QAQuestion] {
        [
            QAQuestion(
                id: "beverage_size",
                question: "How big is your drink?",
                options: [
                    QAOption(id: "small",       value: "small",       label: "Small glass",  hint: "~150ml"),
                    QAOption(id: "standard",    value: "standard",    label: "Medium glass", hint: "~250ml"),
                    QAOption(id: "large",       value: "large",       label: "Large glass",  hint: "~400ml"),
                    QAOption(id: "extra_large", value: "extra_large", label: "Large mug",    hint: "~500ml"),
                ],
                required: true,
                affects: "portion_scale"
            ),
            QAQuestion(
                id: "milk_type",
                question: "What type of milk was used?",
                options: [
                    QAOption(id: "none",  value: "none",  label: "No milk",        hint: "Black tea/coffee"),
                    QAOption(id: "whole", value: "whole", label: "Whole milk",      hint: "Full fat"),
                    QAOption(id: "toned", value: "toned", label: "Toned milk",      hint: "Low fat"),
                    QAOption(id: "oat",   value: "oat",   label: "Oat/plant milk",  hint: ""),
                ],
                required: false,
                affects: "flat_additions"
            ),
            QAQuestion(
                id: "sugar_level",
                question: "How much sugar?",
                options: [
                    QAOption(id: "none",   value: "none",   label: "No sugar",      hint: ""),
                    QAOption(id: "little", value: "little", label: "A little",      hint: "~1 tsp"),
                    QAOption(id: "normal", value: "normal", label: "Normal",         hint: "~2 tsp"),
                    QAOption(id: "extra",  value: "extra",  label: "Extra sweet",   hint: "~3+ tsp"),
                ],
                required: false,
                affects: "flat_additions"
            ),
        ]
    }

    // MARK: - Bread
    private func breadQuestions(dish: DishMatch?) -> [QAQuestion] {
        var q: [QAQuestion] = [
            QAQuestion(
                id: "bread_pieces",
                question: "How many pieces?",
                options: [
                    QAOption(id: "one",   value: "small",       label: "1 piece",    hint: ""),
                    QAOption(id: "two",   value: "standard",    label: "2 pieces",   hint: "Standard"),
                    QAOption(id: "three", value: "large",       label: "3 pieces",   hint: ""),
                    QAOption(id: "four",  value: "extra_large", label: "4+ pieces",  hint: ""),
                ],
                required: true,
                affects: "portion_scale",
                allowsPieceCount: dish?.pieceCountEligible ?? false
            ),
            QAQuestion(
                id: "bread_style",
                question: "Is it stuffed or plain?",
                options: [
                    QAOption(id: "plain",   value: "plain",   label: "Plain",   hint: "No filling"),
                    QAOption(id: "stuffed", value: "stuffed", label: "Stuffed", hint: "Aloo, paneer, etc. +80 kcal"),
                ],
                required: false,
                affects: "flat_additions"
            ),
            QAQuestion(
                id: "cooking_context",
                question: "Where was this made?",
                options: cookingContextOptions(),
                required: true,
                affects: "context_fat"
            ),
        ]
        if (dish?.hasButterInBase ?? 0) == 0 {
            q.append(QAQuestion(
                id: "butter_visible",
                question: "Is there butter or ghee on top?",
                options: [
                    QAOption(id: "none",     value: "none",          label: "None",       hint: ""),
                    QAOption(id: "standard", value: "butter_standard", label: "Light",    hint: "+72 kcal"),
                    QAOption(id: "extra",    value: "butter_extra",    label: "Extra",    hint: "+108 kcal"),
                ],
                required: false,
                affects: "flat_additions"
            ))
        }
        return q
    }

    // MARK: - Rice
    private func riceQuestions(dish: DishMatch?) -> [QAQuestion] {
        [
            QAQuestion(
                id: "rice_amount",
                question: "How much rice is there?",
                options: [
                    QAOption(id: "small_scoop",   value: "small_scoop",   label: "Small scoop",    hint: "~75g"),
                    QAOption(id: "half_cup",       value: "half_cup",      label: "Half cup",       hint: "~125g"),
                    QAOption(id: "standard_cup",   value: "standard_cup",  label: "Standard cup",   hint: "~195g"),
                    QAOption(id: "large_serving",  value: "large_serving", label: "Large serving",  hint: "~320g"),
                    QAOption(id: "full_bowl",      value: "full_bowl",     label: "Full bowl",      hint: "~480g"),
                ],
                required: true,
                affects: "rice_scale",
                allowsManualWeight: true,
                allowsKatori: dish?.katoriEligible ?? false
            ),
            QAQuestion(
                id: "rice_type",
                question: "What type of rice?",
                options: [
                    QAOption(id: "basmati",      value: "basmati",      label: "Basmati",              hint: "Long grain, aromatic"),
                    QAOption(id: "regular",      value: "regular",      label: "Regular white rice",   hint: ""),
                    QAOption(id: "brown",        value: "brown",        label: "Brown rice",           hint: "Higher fibre"),
                    QAOption(id: "sona_masoori", value: "sona_masoori", label: "Sona Masoori",         hint: "South Indian short grain"),
                ],
                required: false,
                affects: "flat_additions"
            ),
            QAQuestion(
                id: "cooking_context",
                question: "Where was this made?",
                options: cookingContextOptions(),
                required: true,
                affects: "context_fat"
            ),
        ]
    }

    // MARK: - Dal / Legume
    private func dalLegumeQuestions(dish: DishMatch?) -> [QAQuestion] {
        [
            QAQuestion(
                id: "portion_size",
                question: "How big is your portion?",
                options: portionSizeOptions(),
                required: true,
                affects: "portion_scale",
                allowsManualWeight: true,
                allowsKatori: dish?.katoriEligible ?? false
            ),
            QAQuestion(
                id: "cooking_context",
                question: "Where was this made?",
                options: cookingContextOptions(),
                required: true,
                affects: "context_fat"
            ),
            QAQuestion(
                id: "gravy_type",
                question: "How would you describe the consistency?",
                options: gravyOptions(),
                required: false,
                affects: "gravy_fat"
            ),
            QAQuestion(
                id: "tadka_type",
                question: "What was used for the tadka (tempering)?",
                options: [
                    QAOption(id: "oil",     value: "oil",     label: "Oil",      hint: "Lighter"),
                    QAOption(id: "ghee",    value: "ghee",    label: "Ghee",     hint: "+45 kcal"),
                    QAOption(id: "butter",  value: "butter",  label: "Butter",   hint: "+45 kcal"),
                    QAOption(id: "unknown", value: "none",    label: "Not sure", hint: ""),
                ],
                required: false,
                affects: "flat_additions"
            ),
            oilGheeQuestion(),
        ]
    }

    // MARK: - Meat / Fish
    private func meatFishQuestions(dish: DishMatch?) -> [QAQuestion] {
        var q: [QAQuestion] = [
            QAQuestion(
                id: "portion_size",
                question: "How big is your portion?",
                options: portionSizeOptions(),
                required: true,
                affects: "portion_scale",
                allowsManualWeight: true
            ),
            QAQuestion(
                id: "meat_amount",
                question: "How much meat is there?",
                options: [
                    QAOption(id: "light",      value: "light",      label: "A few pieces", hint: "~50g"),
                    QAOption(id: "moderate",   value: "moderate",   label: "Moderate",     hint: "~100g"),
                    QAOption(id: "heavy",      value: "heavy",      label: "Heavy",        hint: "~160g"),
                    QAOption(id: "very_heavy", value: "very_heavy", label: "Very heavy",   hint: "~220g"),
                ],
                required: true,
                affects: "meat_scale"
            ),
            QAQuestion(
                id: "bone_in",
                question: "Bone-in or boneless?",
                options: [
                    QAOption(id: "boneless", value: "boneless", label: "Boneless", hint: "More meat per piece"),
                    QAOption(id: "bone_in",  value: "bone_in",  label: "Bone-in",  hint: "Less edible meat"),
                ],
                required: false,
                affects: "meat_scale"
            ),
            QAQuestion(
                id: "cooking_context",
                question: "Where was this made?",
                options: cookingContextOptions(),
                required: true,
                affects: "context_fat"
            ),
            QAQuestion(
                id: "cooking_method",
                question: "How was it cooked?",
                options: [
                    QAOption(id: "curry",   value: "none",             label: "Curry / gravy",  hint: ""),
                    QAOption(id: "tandoor", value: "tandoor",          label: "Tandoor / grilled", hint: "Lower fat"),
                    QAOption(id: "fried",   value: "deep_fried_thin",  label: "Fried",          hint: "Higher fat"),
                    QAOption(id: "dry",     value: "shallow_fried",    label: "Dry / stir-fried", hint: ""),
                ],
                required: false,
                affects: "cooking_method"
            ),
        ]
        if (dish?.hasCreamInBase ?? 0) == 0 {
            q.append(QAQuestion(
                id: "cream_visible",
                question: "Is there cream or sauce on top?",
                options: [
                    QAOption(id: "no",  value: "no",  label: "No",  hint: ""),
                    QAOption(id: "yes", value: "yes", label: "Yes", hint: "+85 kcal"),
                ],
                required: false,
                affects: "flat_additions"
            ))
        }
        q.append(oilGheeQuestion())
        return q
    }

    // MARK: - Vegetable
    private func vegetableQuestions(dish: DishMatch?) -> [QAQuestion] {
        [
            QAQuestion(
                id: "portion_size",
                question: "How big is your portion?",
                options: portionSizeOptions(),
                required: true,
                affects: "portion_scale",
                allowsManualWeight: true,
                allowsKatori: dish?.katoriEligible ?? false
            ),
            QAQuestion(
                id: "cooking_context",
                question: "Where was this made?",
                options: cookingContextOptions(),
                required: true,
                affects: "context_fat"
            ),
            QAQuestion(
                id: "cooking_method",
                question: "How was it cooked?",
                options: [
                    QAOption(id: "sabzi",   value: "shallow_fried",   label: "Dry sabzi",    hint: "Stir-fried"),
                    QAOption(id: "curry",   value: "none",             label: "Curry / gravy", hint: ""),
                    QAOption(id: "steamed", value: "steamed",          label: "Steamed",      hint: "Lower fat"),
                    QAOption(id: "fried",   value: "deep_fried_thin",  label: "Fried",        hint: "Higher fat"),
                ],
                required: false,
                affects: "cooking_method"
            ),
            QAQuestion(
                id: "gravy_type",
                question: "How would you describe the sauce?",
                options: gravyOptions(),
                required: false,
                affects: "gravy_fat"
            ),
            oilGheeQuestion(),
        ]
    }

    // MARK: - Paneer / Dairy
    private func paneerDairyQuestions(dish: DishMatch?) -> [QAQuestion] {
        var q: [QAQuestion] = [
            QAQuestion(
                id: "portion_size",
                question: "How big is your portion?",
                options: portionSizeOptions(),
                required: true,
                affects: "portion_scale",
                allowsManualWeight: true,
                allowsKatori: dish?.katoriEligible ?? false
            ),
            QAQuestion(
                id: "cooking_context",
                question: "Where was this made?",
                options: cookingContextOptions(),
                required: true,
                affects: "context_fat"
            ),
            QAQuestion(
                id: "gravy_type",
                question: "How rich is the gravy?",
                options: gravyOptions(),
                required: false,
                affects: "gravy_fat"
            ),
        ]
        if (dish?.hasCreamInBase ?? 0) == 0 {
            q.append(QAQuestion(
                id: "cream_visible",
                question: "Is there cream or malai on top?",
                options: [
                    QAOption(id: "no",  value: "no",  label: "No",  hint: ""),
                    QAOption(id: "yes", value: "yes", label: "Yes", hint: "+85 kcal"),
                ],
                required: false,
                affects: "flat_additions"
            ))
        }
        q.append(oilGheeQuestion())
        return q
    }

    // MARK: - Snack / Street food
    private func snackStreetQuestions(dish: DishMatch?) -> [QAQuestion] {
        [
            QAQuestion(
                id: "portion_size",
                question: "How much did you have?",
                options: [
                    QAOption(id: "small",       value: "small",       label: "Small portion",  hint: "1-2 pieces"),
                    QAOption(id: "standard",    value: "standard",    label: "Standard",        hint: "3-4 pieces"),
                    QAOption(id: "large",       value: "large",       label: "Large",           hint: "5+ pieces"),
                    QAOption(id: "extra_large", value: "extra_large", label: "Full plate",      hint: ""),
                ],
                required: true,
                affects: "portion_scale",
                allowsManualWeight: true,
                allowsPieceCount: dish?.pieceCountEligible ?? false
            ),
            QAQuestion(
                id: "cooking_context",
                question: "Where was this from?",
                options: [
                    QAOption(id: "home",         value: "home",                  label: "Home made",            hint: ""),
                    QAOption(id: "street_fried", value: "street_fried",          label: "Street stall",         hint: "Deep fried"),
                    QAOption(id: "restaurant",   value: "restaurant",            label: "Restaurant",           hint: ""),
                    QAOption(id: "packaged",     value: "homestyle_restaurant",  label: "Packaged / store-bought", hint: ""),
                ],
                required: true,
                affects: "context_fat"
            ),
            QAQuestion(
                id: "accompaniments",
                question: "Any accompaniments?",
                options: [
                    QAOption(id: "none",       value: "none",       label: "None",              hint: ""),
                    QAOption(id: "chutney",    value: "chutney",    label: "Chutney only",      hint: "+15 kcal"),
                    QAOption(id: "sev_papdi",  value: "sev_papdi",  label: "Sev + papdi",       hint: "+95 kcal"),
                    QAOption(id: "full_chaat", value: "full_chaat", label: "Full chaat toppings", hint: "+120 kcal"),
                ],
                required: false,
                affects: "flat_additions"
            ),
        ]
    }

    // MARK: - Sweet / Dessert
    private func sweetDessertQuestions(dish: DishMatch?) -> [QAQuestion] {
        [
            QAQuestion(
                id: "portion_size",
                question: "How much did you have?",
                options: [
                    QAOption(id: "small",       value: "small",       label: "One small piece",    hint: "~50g"),
                    QAOption(id: "standard",    value: "standard",    label: "One standard piece", hint: "~80g"),
                    QAOption(id: "large",       value: "large",       label: "Two pieces",         hint: "~160g"),
                    QAOption(id: "extra_large", value: "extra_large", label: "Small bowl",         hint: "~200g"),
                ],
                required: true,
                affects: "portion_scale",
                allowsManualWeight: true,
                allowsPieceCount: dish?.pieceCountEligible ?? false
            ),
            QAQuestion(
                id: "sweet_context",
                question: "Where was this from?",
                options: [
                    QAOption(id: "home",        value: "home",                 label: "Home made",            hint: ""),
                    QAOption(id: "mithai_shop", value: "restaurant",           label: "Mithai shop",          hint: "Richer, more ghee"),
                    QAOption(id: "restaurant",  value: "homestyle_restaurant", label: "Restaurant dessert",   hint: ""),
                    QAOption(id: "packaged",    value: "home",                 label: "Packaged / store-bought", hint: ""),
                ],
                required: false,
                affects: "context_fat"
            ),
        ]
    }

    // MARK: - Condiment / Side
    private func condimentQuestions() -> [QAQuestion] {
        [
            QAQuestion(
                id: "portion_size",
                question: "How much?",
                options: [
                    QAOption(id: "tiny",     value: "tiny",     label: "Small spoon", hint: "~15g"),
                    QAOption(id: "small",    value: "small",    label: "Large spoon", hint: "~30g"),
                    QAOption(id: "standard", value: "standard", label: "Small bowl",  hint: "~60g"),
                    QAOption(id: "large",    value: "large",    label: "Large bowl",  hint: "~120g"),
                ],
                required: true,
                affects: "portion_scale",
                allowsManualWeight: true
            ),
        ]
    }

    // MARK: - Default (other / unknown category)
    private func defaultQuestions(dish: DishMatch?) -> [QAQuestion] {
        var q: [QAQuestion] = [
            QAQuestion(
                id: "portion_size",
                question: "How big is your portion?",
                options: portionSizeOptions(),
                required: true,
                affects: "portion_scale"
            ),
            QAQuestion(
                id: "cooking_context",
                question: "Where was this made?",
                options: cookingContextOptions(),
                required: true,
                affects: "context_fat"
            ),
        ]
        if (dish?.hasCreamInBase ?? 0) == 0 {
            q.append(QAQuestion(
                id: "cream_visible",
                question: "Is there cream or malai on top?",
                options: [
                    QAOption(id: "no",  value: "no",  label: "No",  hint: ""),
                    QAOption(id: "yes", value: "yes", label: "Yes", hint: "+85 kcal"),
                ],
                required: false,
                affects: "flat_additions"
            ))
        }
        if (dish?.hasButterInBase ?? 0) == 0 {
            q.append(QAQuestion(
                id: "butter_visible",
                question: "Is there visible butter on top?",
                options: [
                    QAOption(id: "none",     value: "none",            label: "None",        hint: ""),
                    QAOption(id: "standard", value: "butter_standard", label: "Some butter", hint: "+72 kcal"),
                    QAOption(id: "extra",    value: "butter_extra",    label: "Extra butter", hint: "+108 kcal"),
                ],
                required: false,
                affects: "flat_additions"
            ))
        }
        return q
    }

    // MARK: - Shared option sets

    private func portionSizeOptions() -> [QAOption] {
        [
            QAOption(id: "small",       value: "small",       label: "Small",      hint: "About the size of a tennis ball"),
            QAOption(id: "standard",    value: "standard",    label: "Standard",   hint: "Two fists together"),
            QAOption(id: "large",       value: "large",       label: "Large",      hint: "Large bowl or heaped plate"),
            QAOption(id: "extra_large", value: "extra_large", label: "Very large", hint: "Dinner plate piled high"),
        ]
    }

    private func cookingContextOptions() -> [QAOption] {
        [
            QAOption(id: "home",                 value: "home",                 label: "Home cooked",              hint: ""),
            QAOption(id: "homestyle_restaurant", value: "homestyle_restaurant", label: "Small local restaurant",   hint: ""),
            QAOption(id: "restaurant",           value: "restaurant",           label: "Sit-down restaurant",      hint: ""),
            QAOption(id: "dhaba",                value: "dhaba",                label: "Dhaba or highway",         hint: "Heavy oil and ghee"),
            QAOption(id: "street_fried",         value: "street_fried",         label: "Street food – fried",      hint: ""),
            QAOption(id: "street_nonfried",      value: "street_nonfried",      label: "Street food – not fried",  hint: ""),
            QAOption(id: "wedding_banquet",      value: "wedding_banquet",      label: "Wedding or banquet",       hint: "Maximum richness"),
        ]
    }

    /// Optional, skippable oil/ghee add-on (dal_legume, vegetable, meat_fish,
    /// paneer_dairy only). No button options - QuestionView renders a tsp
    /// stepper for this id instead. Skipping (the existing required:false
    /// path) leaves oilGheeTsp nil, which the backend treats as 0.
    private func oilGheeQuestion() -> QAQuestion {
        QAQuestion(
            id: "oil_ghee_extra",
            question: "Add extra oil or ghee?",
            options: [],
            required: false,
            affects: "oil_ghee_additive"
        )
    }

    private func gravyOptions() -> [QAOption] {
        [
            QAOption(id: "dry",        value: "dry",        label: "Dry",        hint: "No sauce"),
            QAOption(id: "thin",       value: "thin",       label: "Thin",       hint: "Watery like rasam"),
            QAOption(id: "medium",     value: "medium",     label: "Medium",     hint: "Standard curry"),
            QAOption(id: "thick",      value: "thick",      label: "Thick",      hint: "Rich and coating"),
            QAOption(id: "very_thick", value: "very_thick", label: "Very thick", hint: "Like butter chicken"),
        ]
    }

    // MARK: - Build QAAnswers from user responses

    func buildQAAnswers(from responses: [String: String],
                        questions: [QAQuestion]) -> QAAnswers {
        var answers = QAAnswers()
        var skipped = 0

        for question in questions {
            guard let response = responses[question.id] else {
                if question.required { skipped += 1 }
                continue
            }
            // Manual weight entry ("manual:<grams>") replaces the bucket answer
            if question.allowsManualWeight,
               response.hasPrefix(Self.manualWeightPrefix),
               let grams = Double(response.dropFirst(Self.manualWeightPrefix.count)) {
                answers.manualWeightG = grams
                continue
            }
            // Katori-count entry ("katori:<count>") replaces the bucket answer
            if question.allowsKatori,
               response.hasPrefix(Self.katoriPrefix),
               let count = Double(response.dropFirst(Self.katoriPrefix.count)) {
                answers.katoriCount = count
                continue
            }
            // Piece-count entry ("piece:<count>") replaces the bucket answer
            if question.allowsPieceCount,
               response.hasPrefix(Self.piecePrefix),
               let count = Double(response.dropFirst(Self.piecePrefix.count)) {
                answers.pieceCount = count
                continue
            }

            switch question.id {
            case "oil_ghee_extra":
                answers.oilGheeTsp = Double(response)
            case "portion_size", "beverage_size", "bread_pieces":
                answers.portionSize = response
            case "cooking_context", "sweet_context":
                answers.cookingContext = response
            case "rice_amount":
                answers.riceAmount = response
            case "meat_amount":
                answers.meatAmount = response
            case "gravy_type":
                answers.gravyType = response
            case "cooking_method":
                if response != "none" { answers.cookingMethod = response }
            case "cream_visible":
                if response == "yes" { answers.flatAdditions.append("cream_dollop") }
            case "butter_visible":
                if response != "none" { answers.flatAdditions.append(response) }
            case "tadka_type":
                if response == "ghee" || response == "butter" {
                    answers.flatAdditions.append("butter_standard")
                }
            case "bread_style":
                if response == "stuffed" { answers.flatAdditions.append("paneer_extra") }
            case "accompaniments":
                if response == "sev_papdi" || response == "full_chaat" {
                    answers.flatAdditions.append("sev_papdi_topping")
                }
            case "bone_in":
                if response == "bone_in" {
                    answers.meatAmount = scaleMeatForBoneIn(answers.meatAmount ?? "moderate")
                }
            default:
                break
            }
        }

        answers.questionsSkipped = skipped
        return answers
    }

    // Bone-in reduces effective meat weight by ~30%
    private func scaleMeatForBoneIn(_ current: String) -> String {
        switch current {
        case "very_heavy": return "heavy"
        case "heavy":      return "moderate"
        case "moderate":   return "light"
        default:           return "light"
        }
    }
}
