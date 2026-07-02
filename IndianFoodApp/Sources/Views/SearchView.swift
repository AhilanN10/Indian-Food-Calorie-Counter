import SwiftUI

// MARK: - SearchView

struct SearchView: View {
    let onSelect: (SearchResult) -> Void
    let onCancel: () -> Void

    @StateObject private var vm = SearchViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // ── Search bar ──────────────────────────────────────────────────
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search Indian dishes…", text: $vm.query)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .onSubmit { Task { await vm.search() } }
                    if !vm.query.isEmpty {
                        Button {
                            vm.query = ""
                            vm.results = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)

                Button("Cancel", action: onCancel)
                    .foregroundColor(.orange)
            }
            .padding()

            // ── Category filter pills ───────────────────────────────────────
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryPill(label: "All", isSelected: vm.selectedCategory == nil) {
                        vm.selectedCategory = nil
                        Task { await vm.search() }
                    }
                    ForEach(SearchViewModel.categories, id: \.self) { cat in
                        CategoryPill(
                            label: cat.replacingOccurrences(of: "_", with: " ").capitalized,
                            isSelected: vm.selectedCategory == cat
                        ) {
                            vm.selectedCategory = (vm.selectedCategory == cat) ? nil : cat
                            Task { await vm.search() }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            Divider()

            // ── Results area ────────────────────────────────────────────────
            if vm.isLoading {
                Spacer()
                ProgressView()
                Spacer()

            } else if !vm.query.isEmpty && vm.results.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No dishes found for \(vm.query)")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()

            } else if vm.query.isEmpty {
                // Browse mode — show category tiles
                BrowseView(browse: vm.browseData, onSelect: onSelect)

            } else {
                List(vm.results) { result in
                    Button {
                        onSelect(result)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.foodName)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                HStack(spacing: 6) {
                                    if let kcal = result.energyKcalPerServing {
                                        Text("\(Int(kcal)) kcal")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if let cat = result.foodCategory {
                                        Text("· \(cat.replacingOccurrences(of: "_", with: " "))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    // Match badge
                                    Text(result.matchType)
                                        .font(.caption2)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(matchColor(result.matchType).opacity(0.15))
                                        .foregroundColor(matchColor(result.matchType))
                                        .clipShape(Capsule())
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Search Dishes")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.loadBrowse() }
        .onChange(of: vm.query) { _ in
            Task {
                // 400ms debounce
                try? await Task.sleep(nanoseconds: 400_000_000)
                await vm.search()
            }
        }
    }

    private func matchColor(_ type: String) -> Color {
        switch type {
        case "exact":  return .green
        case "alias":  return .blue
        case "fuzzy":  return .orange
        default:       return .secondary
        }
    }
}

// MARK: - CategoryPill

struct CategoryPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.orange : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - BrowseView

struct BrowseView: View {
    let browse: BrowseResponse?
    let onSelect: (SearchResult) -> Void

    var body: some View {
        ScrollView {
            if let browse {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(browse.categories.keys.sorted(), id: \.self) { category in
                        if let dishes = browse.categories[category], !dishes.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(category.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.headline)
                                    .padding(.horizontal)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(dishes, id: \.foodCode) { dish in
                                            Button {
                                                onSelect(SearchResult(
                                                    foodCode:             dish.foodCode,
                                                    foodName:             dish.foodName,
                                                    energyKcalPerServing: dish.energyKcalPerServing,
                                                    matchType:            "browse",
                                                    matchScore:           100,
                                                    foodCategory:         category
                                                ))
                                            } label: {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    Text(dish.foodName)
                                                        .font(.subheadline)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.primary)
                                                        .lineLimit(2)
                                                        .multilineTextAlignment(.leading)
                                                    if let kcal = dish.energyKcalPerServing {
                                                        Text("\(Int(kcal)) kcal")
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                .frame(width: 140, alignment: .leading)
                                                .padding(12)
                                                .background(Color(.systemGray6))
                                                .cornerRadius(12)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                    Text("Loading dishes…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            }
        }
    }
}

// MARK: - SearchViewModel

@MainActor
class SearchViewModel: ObservableObject {
    @Published var query            = ""
    @Published var results: [SearchResult] = []
    @Published var isLoading        = false
    @Published var selectedCategory: String? = nil
    @Published var browseData: BrowseResponse? = nil

    private let api = APIService()

    static let categories: [String] = [
        "rice", "bread", "dal_legume", "meat_fish",
        "vegetable", "paneer_dairy", "snack_street",
        "sweet_dessert", "beverage",
    ]

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        isLoading = true
        let response = try? await api.searchDishes(
            query: trimmed,
            limit: 8,
            category: selectedCategory
        )
        results   = response?.results ?? []
        isLoading = false
    }

    func loadBrowse() async {
        guard browseData == nil else { return }
        browseData = try? await api.browseDishes()
    }
}
