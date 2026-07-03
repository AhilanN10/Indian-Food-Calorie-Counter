import SwiftUI
import SwiftData

// MARK: - Daily Goals (hardcoded defaults for now)

struct DailyGoals {
    static let kcal:    Double = 2000
    static let protein: Double = 150
    static let carbs:   Double = 250
    static let fat:     Double = 65
}

// MARK: - DashboardView

struct DashboardView: View {
    @Query private var allLogs: [MealLog]

    private var todayLogs: [MealLog] {
        let calendar = Calendar.current
        return allLogs.filter { calendar.isDateInToday($0.loggedAt) }
    }

    private var totalKcal:    Double { todayLogs.reduce(0) { $0 + $1.kcalEstimate } }
    private var totalProtein: Double { todayLogs.reduce(0) { $0 + $1.proteinG } }
    private var totalCarbs:   Double { todayLogs.reduce(0) { $0 + $1.carbG } }
    private var totalFat:     Double { todayLogs.reduce(0) { $0 + $1.fatG } }

    private var kcalRemaining: Double { max(0, DailyGoals.kcal - totalKcal) }
    private var kcalProgress:  Double { min(1.0, totalKcal / DailyGoals.kcal) }

    private var mealGroups: [(MealType, [MealLog])] {
        MealType.allCases.compactMap { type in
            let meals = todayLogs.filter { $0.mealType == type.rawValue }
            return meals.isEmpty ? nil : (type, meals)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    CalorieRingCard(
                        consumed:  totalKcal,
                        goal:      DailyGoals.kcal,
                        remaining: kcalRemaining,
                        progress:  kcalProgress
                    )

                    MacroBarsCard(
                        protein:     totalProtein, proteinGoal: DailyGoals.protein,
                        carbs:       totalCarbs,   carbsGoal:   DailyGoals.carbs,
                        fat:         totalFat,     fatGoal:     DailyGoals.fat
                    )

                    if todayLogs.isEmpty {
                        EmptyDashboardCard()
                    } else {
                        ForEach(mealGroups, id: \.0) { type, meals in
                            MealGroupCard(mealType: type, meals: meals)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle(dateTitle)
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
        }
    }

    private var dateTitle: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }
}

// MARK: - Calorie Ring Card

struct CalorieRingCard: View {
    let consumed:  Double
    let goal:      Double
    let remaining: Double
    let progress:  Double

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.15), lineWidth: 16)
                    .frame(width: 180, height: 180)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.orange,
                            style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: progress)
                VStack(spacing: 4) {
                    Text("\(Int(consumed))")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                        .contentTransition(.numericText())
                    Text("of \(Int(goal)) kcal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            HStack(spacing: 32) {
                StatPill(label: "Consumed",  value: "\(Int(consumed))",  color: .orange)
                StatPill(label: "Remaining", value: "\(Int(remaining))", color: .green)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct StatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Macro Bars Card

struct MacroBarsCard: View {
    let protein: Double;     let proteinGoal: Double
    let carbs: Double;       let carbsGoal:   Double
    let fat: Double;         let fatGoal:     Double

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Macros")
                .font(.headline)
            DashMacroBar(label: "Protein", current: protein, goal: proteinGoal, color: .blue)
            DashMacroBar(label: "Carbs",   current: carbs,   goal: carbsGoal,   color: .green)
            DashMacroBar(label: "Fat",     current: fat,     goal: fatGoal,     color: .orange)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// Renamed to avoid collision with the MacroBar in ResultsView.swift
struct DashMacroBar: View {
    let label:   String
    let current: Double
    let goal:    Double
    let color:   Color

    var progress: Double { min(1.0, goal > 0 ? current / goal : 0) }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(current))g / \(Int(goal))g")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.15))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: 10)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 10)
        }
    }
}

// MARK: - Meal Group Card

struct MealGroupCard: View {
    let mealType: MealType
    let meals: [MealLog]
    @Environment(\.modelContext) private var modelContext

    var totalKcal: Int { Int(meals.reduce(0) { $0 + $1.kcalEstimate }) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Image(systemName: mealType.icon)
                    .foregroundColor(.orange)
                Text(mealType.rawValue)
                    .font(.headline)
                Spacer()
                Text("\(totalKcal) kcal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.horizontal, 16)

            // Meal rows
            ForEach(meals) { meal in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(meal.dishName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("P:\(Int(meal.proteinG))g  C:\(Int(meal.carbG))g  F:\(Int(meal.fatG))g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(Int(meal.kcalEstimate)) kcal")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        modelContext.delete(meal)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }

                if meal.id != meals.last?.id {
                    Divider().padding(.leading, 16)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Empty State

struct EmptyDashboardCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 44))
                .foregroundColor(.orange.opacity(0.6))
            Text("No meals logged today")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Tap the Log tab to scan or search for a dish")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}
