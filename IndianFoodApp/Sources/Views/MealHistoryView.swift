import SwiftUI
import SwiftData

struct MealHistoryView: View {
    @Query(sort: \MealLog.loggedAt, order: .reverse) private var logs: [MealLog]
    @Environment(\.modelContext) private var modelContext

    // MARK: - Grouped logs by date

    private var groupedLogs: [(String, [MealLog])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let grouped = Dictionary(grouping: logs) { formatter.string(from: $0.loggedAt) }
        return grouped.sorted { a, b in
            let df = DateFormatter()
            df.dateStyle = .medium
            return (df.date(from: a.key) ?? .distantPast) >
                   (df.date(from: b.key) ?? .distantPast)
        }
    }

    // MARK: - Daily totals

    private var todayKcal: Int {
        let cal = Calendar.current
        return Int(logs
            .filter { cal.isDateInToday($0.loggedAt) }
            .reduce(0) { $0 + $1.kcalEstimate })
    }

    // MARK: - Body

    var body: some View {
        Group {
            if logs.isEmpty {
                emptyState
            } else {
                logList
            }
        }
        .navigationTitle("Meal History")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "fork.knife")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No meals logged yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Scan a dish and tap 'Add to Meal'\nto start tracking")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Log list

    private var logList: some View {
        List {
            // Today's kcal summary banner
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(todayKcal) kcal")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    Spacer()
                    Image(systemName: "flame.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.orange.opacity(0.8))
                }
                .padding(.vertical, 6)
            }

            // Grouped by day
            ForEach(groupedLogs, id: \.0) { date, meals in
                Section(header: DateSectionHeader(date: date, meals: meals)) {
                    ForEach(meals) { meal in
                        MealLogRow(meal: meal)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            modelContext.delete(meals[index])
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - DateSectionHeader

struct DateSectionHeader: View {
    let date: String
    let meals: [MealLog]

    var totalKcal: Int { Int(meals.reduce(0) { $0 + $1.kcalEstimate }) }

    var body: some View {
        HStack {
            Text(date)
            Spacer()
            Text("\(totalKcal) kcal total")
                .font(.caption)
                .foregroundColor(.orange)
        }
    }
}

// MARK: - MealLogRow

struct MealLogRow: View {
    let meal: MealLog

    private var timeString: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: meal.loggedAt)
    }

    private var mealIcon: String {
        MealType(rawValue: meal.mealType)?.icon ?? "fork.knife"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: mealIcon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(meal.dishName)
                    .font(.body)
                    .fontWeight(.medium)
                HStack(spacing: 6) {
                    Text(meal.mealType)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(timeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(Int(meal.kcalEstimate)) kcal")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                HStack(spacing: 4) {
                    Text("P:\(Int(meal.proteinG))g")
                    Text("C:\(Int(meal.carbG))g")
                    Text("F:\(Int(meal.fatG))g")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
