import Foundation

class QuestionEngine: ObservableObject {

    // MARK: - Question generation

    func generateQuestions(for dish: DishMatch?,
                           classificationResult: ClassificationResult?) -> [QAQuestion] {
        var questions: [QAQuestion] = []
        let category   = dish?.foodCategory ?? ""
        let className  = classificationResult?.className ?? ""

        // ── Portion size (always shown) ────────────────────────────────────
        questions.append(QAQuestion(
            id: "portion_size",
            question: "How big is your portion?",
            options: [
                QAOption(id: "tiny",        value: "tiny",        label: "Tiny",       hint: "A few bites"),
                QAOption(id: "small",       value: "small",       label: "Small",      hint: "About a tennis ball"),
                QAOption(id: "standard",    value: "standard",    label: "Standard",   hint: "Two fists together"),
                QAOption(id: "large",       value: "large",       label: "Large",      hint: "Large bowl or heaped plate"),
                QAOption(id: "extra_large", value: "extra_large", label: "Very large", hint: "Dinner plate piled high"),
            ],
            required: true,
            affects: "portion_scale"
        ))

        // ── Cooking context (always shown) ─────────────────────────────────
        questions.append(QAQuestion(
            id: "cooking_context",
            question: "Where was this made?",
            options: [
                QAOption(id: "home",                 value: "home",                 label: "Home cooked",         hint: ""),
                QAOption(id: "homestyle_restaurant", value: "homestyle_restaurant", label: "Small local restaurant", hint: ""),
                QAOption(id: "restaurant",           value: "restaurant",           label: "Sit-down restaurant", hint: ""),
                QAOption(id: "dhaba",                value: "dhaba",                label: "Dhaba or highway",    hint: "Heavy oil and ghee"),
                QAOption(id: "street_fried",         value: "street_fried",         label: "Street food – fried", hint: ""),
                QAOption(id: "street_nonfried",      value: "street_nonfried",      label: "Street food – not fried", hint: ""),
                QAOption(id: "wedding_banquet",      value: "wedding_banquet",      label: "Wedding or banquet",  hint: "Maximum richness"),
            ],
            required: true,
            affects: "context_fat"
        ))

        // ── Rice amount (rice dishes only) ─────────────────────────────────
        let isRice = category == "rice"
            || className.contains("biryani") || className.contains("rice")
            || className.contains("pulao")
        if isRice {
            questions.append(QAQuestion(
                id: "rice_amount",
                question: "How much rice is there?",
                options: [
                    QAOption(id: "small_scoop",    value: "small_scoop",    label: "Small scoop",    hint: "~75 g"),
                    QAOption(id: "half_cup",        value: "half_cup",       label: "Half cup",       hint: "~125 g"),
                    QAOption(id: "standard_cup",    value: "standard_cup",   label: "Standard cup",   hint: "~195 g"),
                    QAOption(id: "large_serving",   value: "large_serving",  label: "Large serving",  hint: "~320 g"),
                    QAOption(id: "full_bowl",       value: "full_bowl",      label: "Full bowl",      hint: "~480 g"),
                ],
                required: false,
                affects: "rice_scale"
            ))
        }

        // ── Meat amount (meat dishes only) ─────────────────────────────────
        let isMeat = category == "meat_fish"
        if isMeat {
            questions.append(QAQuestion(
                id: "meat_amount",
                question: "How much meat is there?",
                options: [
                    QAOption(id: "light",      value: "light",      label: "A few pieces", hint: "~50 g"),
                    QAOption(id: "moderate",   value: "moderate",   label: "Moderate",     hint: "~100 g"),
                    QAOption(id: "heavy",      value: "heavy",      label: "Heavy",        hint: "~160 g"),
                    QAOption(id: "very_heavy", value: "very_heavy", label: "Very heavy",   hint: "~220 g"),
                ],
                required: false,
                affects: "meat_scale"
            ))
        }

        // ── Gravy type (wet dishes) ────────────────────────────────────────
        let hasGravy = ["dal_legume", "vegetable", "paneer_dairy", "meat_fish"].contains(category)
        if hasGravy {
            questions.append(QAQuestion(
                id: "gravy_type",
                question: "How would you describe the sauce?",
                options: [
                    QAOption(id: "dry",        value: "dry",        label: "Dry",        hint: "No sauce at all"),
                    QAOption(id: "thin",        value: "thin",       label: "Thin",       hint: "Watery, like rasam"),
                    QAOption(id: "medium",      value: "medium",     label: "Medium",     hint: "Standard curry"),
                    QAOption(id: "thick",       value: "thick",      label: "Thick",      hint: "Rich and coating"),
                    QAOption(id: "very_thick",  value: "very_thick", label: "Very thick", hint: "Like makhani or korma"),
                ],
                required: false,
                affects: "gravy_fat"
            ))
        }

        // ── Cream on top (only if not already in base) ─────────────────────
        if (dish?.hasCreamInBase ?? 0) == 0 {
            questions.append(QAQuestion(
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

        // ── Butter on top (only if not already in base) ────────────────────
        if (dish?.hasButterInBase ?? 0) == 0 {
            questions.append(QAQuestion(
                id: "butter_visible",
                question: "Is there visible butter on top?",
                options: [
                    QAOption(id: "none",     value: "none",            label: "None",         hint: ""),
                    QAOption(id: "standard", value: "butter_standard", label: "Some butter",  hint: "+72 kcal"),
                    QAOption(id: "extra",    value: "butter_extra",    label: "Extra butter", hint: "+108 kcal"),
                ],
                required: false,
                affects: "flat_additions"
            ))
        }

        return questions
    }

    // MARK: - Answer compilation

    func buildQAAnswers(from responses: [String: String],
                        questions: [QAQuestion]) -> QAAnswers {
        var answers = QAAnswers()
        var skipped = 0

        for question in questions {
            guard let response = responses[question.id] else {
                if question.required { skipped += 1 }
                continue
            }
            switch question.id {
            case "portion_size":    answers.portionSize    = response
            case "cooking_context": answers.cookingContext = response
            case "rice_amount":     answers.riceAmount     = response
            case "meat_amount":     answers.meatAmount     = response
            case "gravy_type":      answers.gravyType      = response
            case "cream_visible":
                if response == "yes" { answers.flatAdditions.append("cream_dollop") }
            case "butter_visible":
                if response != "none" { answers.flatAdditions.append(response) }
            default:
                break
            }
        }

        answers.questionsSkipped = skipped
        return answers
    }
}
