import SwiftUI
import SwiftData

struct BarcodeResultView: View {
    let result: BarcodeResult
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var selectedMealType:  MealType = .lunch
    @State private var servingMultiplier: Double   = 1.0
    @State private var isLogged:          Bool     = false
    @State private var useServingSize:    Bool

    init(result: BarcodeResult, onDone: @escaping () -> Void) {
        self.result = result
        self.onDone = onDone
        _useServingSize = State(initialValue: result.kcalPerServing != nil)
    }

    // MARK: - Computed display values

    private var displayKcal: Double {
        if useServingSize, let s = result.kcalPerServing { return s * servingMultiplier }
        return result.kcalPer100g * servingMultiplier
    }
    private var displayProtein: Double {
        if useServingSize, let s = result.proteinPerServing { return s * servingMultiplier }
        return result.proteinPer100g * servingMultiplier
    }
    private var displayCarbs: Double {
        if useServingSize, let s = result.carbsPerServing { return s * servingMultiplier }
        return result.carbsPer100g * servingMultiplier
    }
    private var displayFat: Double {
        if useServingSize, let s = result.fatPerServing { return s * servingMultiplier }
        return result.fatPer100g * servingMultiplier
    }
    private var displayFibre: Double {
        if useServingSize, let s = result.fibrePerServing { return s * servingMultiplier }
        return result.fibrePer100g * servingMultiplier
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Product header
                VStack(spacing: 6) {
                    Text(result.productName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    if !result.brand.isEmpty {
                        Text(result.brand)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Label(result.barcode, systemImage: "barcode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top)

                // Calorie display
                VStack(spacing: 4) {
                    Text("\(Int(displayKcal))")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                        .contentTransition(.numericText())
                    Text("kcal")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemGray6)))
                .padding(.horizontal)

                // Macro grid (reuses MacroCard from ResultsView.swift)
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()),
                              GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 16
                ) {
                    MacroCard(label: "Protein", value: displayProtein, unit: "g", color: .blue,   pct: nil)
                    MacroCard(label: "Carbs",   value: displayCarbs,   unit: "g", color: .green,  pct: nil)
                    MacroCard(label: "Fat",     value: displayFat,     unit: "g", color: .orange, pct: nil)
                    MacroCard(label: "Fibre",   value: displayFibre,   unit: "g", color: .purple, pct: nil)
                }
                .padding(.horizontal)

                // Serving controls
                VStack(spacing: 12) {
                    if result.kcalPerServing != nil {
                        Toggle(
                            "Use serving size\(result.servingSize.map { " (\($0))" } ?? "")",
                            isOn: $useServingSize
                        )
                        .tint(.orange)
                        .padding(.horizontal)
                    }

                    HStack {
                        Text("Servings:")
                            .font(.subheadline)
                        Spacer()
                        Button {
                            if servingMultiplier > 0.5 {
                                servingMultiplier = ((servingMultiplier - 0.5) * 10).rounded() / 10
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                        }
                        Text(String(format: "%.1f", servingMultiplier))
                            .font(.headline)
                            .frame(width: 44)
                        Button {
                            servingMultiplier = ((servingMultiplier + 0.5) * 10).rounded() / 10
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)))
                .padding(.horizontal)

                // Meal type + log button
                VStack(spacing: 12) {
                    Text("Log this item")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(MealType.allCases, id: \.self) { type in
                                Button { selectedMealType = type } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: type.icon)
                                        Text(type.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedMealType == type
                                                ? Color.orange : Color(.systemGray6))
                                    .foregroundColor(selectedMealType == type ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .animation(.easeInOut(duration: 0.15), value: selectedMealType)
                            }
                        }
                        .padding(.horizontal)
                    }

                    Button { logItem() } label: {
                        HStack {
                            Image(systemName: isLogged ? "checkmark.circle.fill" : "plus.circle.fill")
                            Text(isLogged ? "Logged!" : "Add to \(selectedMealType.rawValue)")
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
                }

                // Done button
                Button(action: onDone) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(14)
                        .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Product Found")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Log

    private func logItem() {
        let log = MealLog(
            dishName:     result.productName,
            foodCode:     result.barcode,
            kcalEstimate: displayKcal,
            proteinG:     displayProtein,
            fatG:         displayFat,
            carbG:        displayCarbs,
            fibreG:       displayFibre,
            mealType:     selectedMealType.rawValue
        )
        modelContext.insert(log)
        withAnimation { isLogged = true }

        Task {
            let hk = HealthKitService.shared
            if !hk.isAuthorized { await hk.requestAuthorization() }
            if hk.isAuthorized {
                _ = await hk.logMeal(
                    dishName: result.productName,
                    kcal:     displayKcal,
                    protein:  displayProtein,
                    carbs:    displayCarbs,
                    fat:      displayFat,
                    fibre:    displayFibre
                )
            }
        }
    }
}
