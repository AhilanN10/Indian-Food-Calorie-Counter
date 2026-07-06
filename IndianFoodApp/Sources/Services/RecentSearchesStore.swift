import Foundation

// MARK: - RecentSearchesStore

/// Tracks the last N unique search queries, most recent first.
/// Persisted via UserDefaults — mirrors ProfileStore's simple persistence pattern.
final class RecentSearchesStore: ObservableObject {
    @Published private(set) var queries: [String] = [] {
        didSet { persist() }
    }

    private let defaultsKey = "recentSearchQueries"
    private let maxCount    = 10

    init() { load() }

    // MARK: - Public API

    /// Adds a query to the front of the list, moving it there if it already exists.
    func add(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var updated = queries
        updated.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        updated.insert(trimmed, at: 0)
        if updated.count > maxCount {
            updated = Array(updated.prefix(maxCount))
        }
        queries = updated
    }

    func remove(_ query: String) {
        queries.removeAll { $0 == query }
    }

    func remove(at offsets: IndexSet) {
        queries.remove(atOffsets: offsets)
    }

    func clearAll() {
        queries = []
    }

    // MARK: - Persistence

    private func load() {
        queries = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
    }

    private func persist() {
        UserDefaults.standard.set(queries, forKey: defaultsKey)
    }
}
