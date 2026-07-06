import SwiftUI
import SwiftData

// MARK: - SearchView

struct SearchView: View {
    let onSelect: (SearchResult) -> Void
    let onCancel: () -> Void
    var onBarcodeScan: (() -> Void)? = nil
    /// Optional: called when the user taps the Fasting Mode pill to change it
    /// elsewhere (Profile tab). nil-safe no-op if the caller doesn't wire it.
    var onOpenFastingSettings: (() -> Void)? = nil

    @EnvironmentObject private var profileStore: ProfileStore
    @StateObject private var vm = SearchViewModel()
    @StateObject private var recentSearchesStore = RecentSearchesStore()
    @ObservedObject private var fastingModeStore = FastingModeStore.shared

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavoriteDish.dateAdded, order: .reverse) private var favorites: [FavoriteDish]

    @State private var showFiltersSheet = false
    @State private var draftDietaryFilters: Set<DietaryFilter> = []

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
                        .onSubmit {
                            recentSearchesStore.add(vm.query)
                            Task { await vm.searchNow() }
                        }
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
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(14)

                Button("Cancel", action: onCancel)
                    .foregroundColor(.orange)

                if let onBarcodeScan {
                    Button(action: onBarcodeScan) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.title3)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()

            // ── Category chips + Filters pill (single scrollable row) ───────
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryPill(label: "All", isSelected: vm.selectedCategory == nil) {
                        vm.selectedCategory = nil
                        Task { await vm.searchNow() }
                    }
                    ForEach(SearchViewModel.categories, id: \.self) { cat in
                        CategoryPill(
                            label: cat.replacingOccurrences(of: "_", with: " ").capitalized,
                            isSelected: vm.selectedCategory == cat
                        ) {
                            vm.selectedCategory = (vm.selectedCategory == cat) ? nil : cat
                            Task { await vm.searchNow() }
                        }
                    }
                    FiltersPillButton(count: vm.dietaryFilters.count) {
                        draftDietaryFilters = vm.dietaryFilters
                        showFiltersSheet = true
                    }
                    FastingModePillButton(mode: fastingModeStore.mode) {
                        onOpenFastingSettings?()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .overlay(fadeEdges)

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
                EmptyQueryContent(
                    favorites:           favorites,
                    recentSearches:      recentSearchesStore.queries,
                    browse:              vm.browseData,
                    onSelectFavorite:    { fav in
                        onSelect(SearchResult(
                            foodCode:             fav.foodCode,
                            foodName:             fav.dishName,
                            energyKcalPerServing: nil,
                            matchType:            "favorite",
                            matchScore:           100,
                            foodCategory:         nil
                        ))
                    },
                    onUnfavorite:        { fav in modelContext.delete(fav) },
                    onTapRecent:         { query in
                        vm.query = query
                        Task { await vm.searchNow() }
                    },
                    onDeleteRecent:      { offsets in recentSearchesStore.remove(at: offsets) },
                    onClearAllRecent:    { recentSearchesStore.clearAll() },
                    onSelectBrowseDish:  { result in onSelect(result) }
                )

            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.results) { result in
                            SearchResultCard(
                                result:     result,
                                isFavorite: isFavorite(result.foodCode),
                                onTap: {
                                    recentSearchesStore.add(vm.query)
                                    onSelect(result)
                                },
                                onToggleFavorite: {
                                    toggleFavorite(foodCode: result.foodCode, dishName: result.foodName)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Search Dishes")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            vm.seedFiltersIfNeeded(from: profileStore.dietaryPreferences)
            vm.fastingMode = fastingModeStore.mode
            await vm.loadBrowse()
        }
        .onChange(of: vm.query) { _ in
            vm.handleQueryChanged()
        }
        .onChange(of: fastingModeStore.mode) { newMode in
            Task { await vm.syncFastingMode(newMode) }
        }
        .sheet(isPresented: $showFiltersSheet) {
            DietaryFiltersSheet(draftFilters: $draftDietaryFilters) {
                Task { await vm.applyDietaryFilters(draftDietaryFilters) }
            }
        }
    }

    // MARK: - Fade edge scroll affordance

    private var fadeEdges: some View {
        HStack {
            LinearGradient(colors: [Color(.systemBackground), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: 18)
            Spacer()
            LinearGradient(colors: [.clear, Color(.systemBackground)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: 18)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Favorites helpers

    private func isFavorite(_ foodCode: String) -> Bool {
        favorites.contains { $0.foodCode == foodCode }
    }

    private func toggleFavorite(foodCode: String, dishName: String) {
        if let existing = favorites.first(where: { $0.foodCode == foodCode }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(FavoriteDish(foodCode: foodCode, dishName: dishName))
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

// MARK: - FiltersPillButton

struct FiltersPillButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "slider.horizontal.3")
                Text(count > 0 ? "Filters (\(count))" : "Filters")
            }
            .font(.caption)
            .fontWeight(count > 0 ? .semibold : .regular)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(count > 0 ? Color.orange : Color(.systemGray6))
            .foregroundColor(count > 0 ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FastingModePillButton

/// Read-only indicator of the active Fasting Mode — the picker itself lives
/// in Profile (single source of truth); tapping this jumps there to change it.
struct FastingModePillButton: View {
    let mode: FastingMode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "moon.stars.fill")
                Text(mode == .none ? "Fasting Mode" : "Fasting: \(mode.displayLabel)")
            }
            .font(.caption)
            .fontWeight(mode == .none ? .regular : .semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(mode == .none ? Color(.systemGray6) : Color.orange)
            .foregroundColor(mode == .none ? .primary : .white)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DietaryFiltersSheet

/// Selections default to the caller's active filters but never write back to the
/// saved Profile preference on their own — the caller decides what "Apply" means.
struct DietaryFiltersSheet: View {
    @Binding var draftFilters: Set<DietaryFilter>
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(DietaryFilter.allCases) { filter in
                    Toggle(filter.displayLabel, isOn: Binding(
                        get: { draftFilters.contains(filter) },
                        set: { isOn in
                            if isOn { draftFilters.insert(filter) }
                            else    { draftFilters.remove(filter) }
                        }
                    ))
                    .tint(.orange)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear All") {
                        draftFilters.removeAll()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - EmptyQueryContent

/// Landing content shown when the search field is empty: Favorites, Recent
/// Searches, then the existing category-browse tiles — so returning users land
/// on their own history instead of a blank screen.
struct EmptyQueryContent: View {
    let favorites: [FavoriteDish]
    let recentSearches: [String]
    let browse: BrowseResponse?
    let onSelectFavorite: (FavoriteDish) -> Void
    let onUnfavorite: (FavoriteDish) -> Void
    let onTapRecent: (String) -> Void
    let onDeleteRecent: (IndexSet) -> Void
    let onClearAllRecent: () -> Void
    let onSelectBrowseDish: (SearchResult) -> Void

    var body: some View {
        List {
            Section {
                if favorites.isEmpty {
                    EmptyStateRow(icon: "heart",
                                  text: "Favorite a dish to see it here for quick re-logging")
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(favorites) { fav in
                                FavoriteCard(
                                    favorite: fav,
                                    onSelect: { onSelectFavorite(fav) },
                                    onToggleFavorite: { onUnfavorite(fav) }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets())
                    .padding(.horizontal)
                }
            } header: {
                Text("Favorites")
            }

            Section {
                if recentSearches.isEmpty {
                    EmptyStateRow(icon: "clock",
                                  text: "Your recent searches will show up here")
                } else {
                    ForEach(recentSearches, id: \.self) { query in
                        Button {
                            onTapRecent(query)
                        } label: {
                            Label(query, systemImage: "clock")
                                .foregroundColor(.primary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                if let index = recentSearches.firstIndex(of: query) {
                                    onDeleteRecent(IndexSet(integer: index))
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Recent Searches")
                    Spacer()
                    if !recentSearches.isEmpty {
                        Button("Clear All", action: onClearAllRecent)
                            .font(.caption)
                            .textCase(nil)
                    }
                }
            }

            if let browse {
                ForEach(browse.categories.keys.sorted(), id: \.self) { category in
                    if let dishes = browse.categories[category], !dishes.isEmpty {
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(dishes, id: \.foodCode) { dish in
                                        Button {
                                            onSelectBrowseDish(SearchResult(
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
                                .padding(.vertical, 4)
                            }
                            .listRowInsets(EdgeInsets())
                            .padding(.horizontal)
                        } header: {
                            Text(category.replacingOccurrences(of: "_", with: " ").capitalized)
                        }
                    }
                }
            } else {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Loading dishes…")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 24)
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - EmptyStateRow

struct EmptyStateRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

// MARK: - FavoriteCard

struct FavoriteCard: View {
    let favorite: FavoriteDish
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Spacer()
                Button(action: onToggleFavorite) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            Text(favorite.dishName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .frame(width: 140, height: 84, alignment: .topLeading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

// MARK: - SearchResultCard

struct SearchResultCard: View {
    let result: SearchResult
    let isFavorite: Bool
    let onTap: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(result.foodName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        if let kcal = result.energyKcalPerServing {
                            Text("\(Int(kcal)) kcal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let cat = result.foodCategory {
                            Text(cat.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                        }
                        if result.matchType == "alias" || result.matchType == "fuzzy" {
                            Text(result.matchType.capitalized)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(matchBadgeColor(result.matchType).opacity(0.15))
                                .foregroundColor(matchBadgeColor(result.matchType))
                                .clipShape(Capsule())
                        }
                    }
                }
                Spacer(minLength: 8)
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(isFavorite ? .red : .secondary)
                        .font(.body)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6).opacity(0.6)))
        }
        .buttonStyle(.plain)
    }
}

private func matchBadgeColor(_ type: String) -> Color {
    switch type {
    case "exact":  return .green
    case "alias":  return .blue
    case "fuzzy":  return .orange
    default:       return .secondary
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
    @Published var dietaryFilters: Set<DietaryFilter> = []
    @Published var fastingMode: FastingMode = .none

    private let api = APIService()
    private var filtersSeeded = false

    /// In-flight search request — cancelled whenever a new search starts, so a
    /// slow earlier response can never overwrite a faster later one.
    private var searchTask: Task<SearchResponse?, Never>?
    /// Debounce timer for search-as-you-type.
    private var debounceTask: Task<Void, Never>?

    static let categories: [String] = [
        "rice", "bread", "dal_legume", "meat_fish",
        "vegetable", "paneer_dairy", "snack_street",
        "sweet_dessert", "beverage",
    ]

    /// Called on every keystroke. Debounces ~300ms before firing the request.
    func handleQueryChanged() {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchTask?.cancel()
            results   = []
            isLoading = false
            return
        }
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.search()
        }
    }

    /// Bypasses the debounce for explicit user actions (submit, category tap,
    /// recent-search tap, filter apply).
    func searchNow() async {
        debounceTask?.cancel()
        await search()
    }

    func search() async {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results   = []
            isLoading = false
            return
        }

        isLoading = true
        let requestCategory = selectedCategory
        let requestFilters  = dietaryFilters
        let requestFasting  = fastingMode
        let task = Task<SearchResponse?, Never> { [api] in
            (try? await api.searchDishes(
                query: trimmed, limit: 8,
                category: requestCategory, dietaryFilters: requestFilters,
                fastingMode: requestFasting
            )) ?? nil
        }
        searchTask = task

        let response = await task.value
        guard !task.isCancelled else { return }

        results   = response?.results ?? []
        isLoading = false
    }

    func loadBrowse(force: Bool = false) async {
        guard force || browseData == nil else { return }
        browseData = try? await api.browseDishes(dietaryFilters: dietaryFilters, fastingMode: fastingMode)
    }

    /// Copy profile preferences into the session filters exactly once per
    /// SearchView appearance. Later chip toggles stay session-local.
    func seedFiltersIfNeeded(from preferences: Set<DietaryFilter>) {
        guard !filtersSeeded else { return }
        dietaryFilters = preferences
        filtersSeeded  = true
    }

    /// Applies a batch of filter changes from the Filters sheet. Session-local,
    /// same as the old per-chip toggle — never writes back to the saved profile.
    func applyDietaryFilters(_ filters: Set<DietaryFilter>) async {
        dietaryFilters = filters
        await loadBrowse(force: true)
        await searchNow()
    }

    /// Reacts to a live change in the shared FastingModeStore (unlike
    /// dietaryFilters, this is NOT session-local — it always reflects the
    /// current standing value, so a change re-runs the active browse/search).
    func syncFastingMode(_ mode: FastingMode) async {
        guard fastingMode != mode else { return }
        fastingMode = mode
        await loadBrowse(force: true)
        await searchNow()
    }
}
