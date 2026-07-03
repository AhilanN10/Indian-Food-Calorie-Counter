import SwiftUI
import SwiftData
import HealthKit

struct ResultsView: View {
    let dishName: String
    let foodCode: String
    let result: MacroResult
    let onDone: () -> Void

    // MARK: - SwiftData + state

    @Environment(\.modelContext) private var modelContext
    @State private var selectedMealType: MealType = .lunch
    @State private var isLogged = false
    @State private var healthKitLogged = false

    // MARK: - Computed

    var confidenceLabel: String {
        switch result.confidenceBandPct {
        case ..<0.15: return "High confidence"
        case ..<0.30: return "Medium confidence"
        case ..<0.45: return "Low confidence"
        default:      return "Rough estimate"
        }
    }

    var confidenceColor: Color {
        switch result.confidenceBandPct {
        case ..<0.15: return .green
        case ..<0.30: return .orange
        default:      return .red
        }
    }

    var totalMacroKcal: Double {
        (result.proteinG * 4) + (result.carbG * 4) + (result.fatG * 9)
    }

    var proteinPct: Double { (result.proteinG * 4) / max(totalMacroKcal, 1) }
    var carbPct:    Double { (result.carbG    * 4) / max(totalMacroKcal, 1) }
    var fatPct:     Double { (result.fatG     * 9) / max(totalMacroKcal, 1) }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Dish name + confidence badge
                VStack(spacing: 6) {
                    Text(dishName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    Label(confidenceLabel, systemImage: "chart.bar.fill")
                        .font(.caption)
                        .foregroundColor(confidenceColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(confidenceColor.opacity(0.12))
                        .clipShape(Capsule())
                }
                .padding(.top)

                // Big kcal number
                VStack(spacing: 4) {
                    Text("\(Int(result.kcalEstimate))")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                        .contentTransition(.numericText())
                    Text("calories")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("\(Int(result.kcalLow)) – \(Int(result.kcalHigh)) kcal range")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemGray6)))
                .padding(.horizontal)

                // Macro cards
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ],
                    spacing: 12
                ) {
                    MacroCard(label: "Protein", value: result.proteinG, unit: "g",
                              color: .blue,   pct: proteinPct)
                    MacroCard(label: "Carbs",   value: result.carbG,    unit: "g",
                              color: .green,  pct: carbPct)
                    MacroCard(label: "Fat",     value: result.fatG,     unit: "g",
                              color: .orange, pct: fatPct)
                    MacroCard(label: "Fibre",   value: result.fibreG,   unit: "g",
                              color: .purple, pct: nil)
                }
                .padding(.horizontal)

                // Macro bar
                MacroBar(proteinPct: proteinPct, carbPct: carbPct, fatPct: fatPct)
                    .padding(.horizontal)

                // Adjustments applied (collapsed detail)
                if !result.adjustmentsApplied.isEmpty {
                    DisclosureGroup("Adjustments applied") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(result.adjustmentsApplied, id: \.self) { adj in
                                Text("• \(adj)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    }
                    .font(.caption)
                    .padding(.horizontal)
                }

                // ── Meal logging ───────────────────────────────────────────
                VStack(spacing: 12) {
                    Text("Log this meal")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    // Meal type selector pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(MealType.allCases, id: \.self) { type in
                                Button {
                                    selectedMealType = type
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: type.icon)
                                        Text(type.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedMealType == type
                                                ? Color.orange
                                                : Color(.systemGray6))
                                    .foregroundColor(selectedMealType == type ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .animation(.easeInOut(duration: 0.15), value: selectedMealType)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Log button
                    Button {
                        logMeal()
                    } label: {
                        HStack {
                            if isLogged {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Logged!")
                            } else {
                                Image(systemName: "plus.circle.fill")
                                Text("Add to \(selectedMealType.rawValue)")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isLogged ? Color.green : Color.orange)
                        .cornerRadius(14)
                        .padding(.horizontal)
                    }
                    .disabled(isLogged)
                    .animation(.easeInOut(duration: 0.2), value: isLogged)

                    // HealthKit status indicator
                    if isLogged {
                        HStack(spacing: 6) {
                            Image(systemName: healthKitLogged
                                  ? "heart.fill"
                                  : "heart.slash")
                                .foregroundColor(healthKitLogged ? .red : .secondary)
                                .font(.caption)
                            Text(healthKitLogged
                                 ? "Also logged to Apple Health"
                                 : "Apple Health not connected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                        .transition(.opacity)
                    }
                }
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6).opacity(0.5)))
                .padding(.horizontal)

                // Done button
                Button(action: onDone) {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(14)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Log meal

    private func logMeal() {
        let log = MealLog(
            dishName: dishName,
            foodCode: foodCode,
            result:   result,
            mealType: selectedMealType.rawValue
        )
        modelContext.insert(log)
        withAnimation { isLogged = true }

        // Also write to Apple Health
        Task {
            let hk = HealthKitService.shared
            if !hk.isAuthorized {
                await hk.requestAuthorization()
            }
            if hk.isAuthorized {
                let success = await hk.logMeal(
                    dishName: dishName,
                    kcal:     result.kcalEstimate,
                    protein:  result.proteinG,
                    carbs:    result.carbG,
                    fat:      result.fatG,
                    fibre:    result.fibreG
                )
                await MainActor.run {
                    withAnimation { healthKitLogged = success }
                }
            }
        }
    }
}

// MARK: - MacroCard

struct MacroCard: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color
    let pct: Double?

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Int(value))\(unit)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            if let pct = pct {
                Text("\(Int(pct * 100))%")
                    .font(.caption2)
                    .foregroundColor(color.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}

// MARK: - MacroBar

struct MacroBar: View {
    let proteinPct: Double
    let carbPct:    Double
    let fatPct:     Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Macro breakdown")
                .font(.caption)
                .foregroundColor(.secondary)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geo.size.width * proteinPct)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green)
                        .frame(width: geo.size.width * carbPct)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange)
                        .frame(width: geo.size.width * fatPct)
                }
            }
            .frame(height: 10)
            .clipShape(RoundedRectangle(cornerRadius: 5))

            HStack(spacing: 12) {
                LegendDot(color: .blue,   label: "Protein")
                LegendDot(color: .green,  label: "Carbs")
                LegendDot(color: .orange, label: "Fat")
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
}
