import Foundation

// MARK: - Request types

struct CalculateRequest: Codable {
    let foodCode: String
    let qaAnswers: QAAnswers
    enum CodingKeys: String, CodingKey {
        case foodCode   = "food_code"
        case qaAnswers  = "qa_answers"
    }
}

// MARK: - API Service

class APIService: ObservableObject {

    // Swap this for your LAN IP when testing on a real device,
    // e.g. "http://192.168.1.10:8000"
    private let baseURL = "http://127.0.0.1:8000"
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private var decoder: JSONDecoder { JSONDecoder() }
    private var encoder: JSONEncoder { JSONEncoder() }

    /// Comma-separated dietaryFilters value (sorted for stable URLs)
    private static func filterParam(_ filters: Set<DietaryFilter>) -> String {
        filters.map(\.rawValue).sorted().joined(separator: ",")
    }

    // MARK: - /dish/search

    func searchDish(query: String) async throws -> DishMatch? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/dish/search?q=\(encoded)")
        else { return nil }

        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? decoder.decode(DishMatch.self, from: data)
    }

    // MARK: - /dish/{food_code}

    func getDish(foodCode: String) async throws -> DishMatch? {
        guard let url = URL(string: "\(baseURL)/dish/\(foodCode)") else { return nil }
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        do {
            return try decoder.decode(DishMatch.self, from: data)
        } catch {
            print("APIService: decode error for \(foodCode): \(error)")
            return nil
        }
    }

    // MARK: - POST /dish/calculate

    func calculateMacros(foodCode: String, qaAnswers: QAAnswers) async throws -> MacroResult? {
        guard let url = URL(string: "\(baseURL)/dish/calculate") else { return nil }
        var request        = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body           = CalculateRequest(foodCode: foodCode, qaAnswers: qaAnswers)
        request.httpBody   = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? decoder.decode(MacroResult.self, from: data)
    }

    // MARK: - /health

    func healthCheck() async -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else { return false }
        guard let (_, response) = try? await session.data(from: url) else { return false }
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    // MARK: - /dish/search  (list shape)

    func searchDishes(query: String, limit: Int = 8, category: String? = nil,
                      dietaryFilters: Set<DietaryFilter> = [],
                      fastingMode: FastingMode = .none) async throws -> SearchResponse? {
        var components = URLComponents(string: "\(baseURL)/dish/search")!
        var queryItems = [
            URLQueryItem(name: "q",     value: query),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        if !dietaryFilters.isEmpty {
            queryItems.append(URLQueryItem(name: "dietaryFilters",
                                           value: Self.filterParam(dietaryFilters)))
        }
        if let fastingParam = fastingMode.queryParam {
            queryItems.append(URLQueryItem(name: "fastingMode", value: fastingParam))
        }
        components.queryItems = queryItems
        guard let url = components.url else { return nil }

        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        do {
            return try decoder.decode(SearchResponse.self, from: data)
        } catch {
            print("APIService: searchDishes decode error: \(error)")
            return nil
        }
    }

    // MARK: - /dish/browse

    func browseDishes(dietaryFilters: Set<DietaryFilter> = [],
                      fastingMode: FastingMode = .none) async throws -> BrowseResponse? {
        var components = URLComponents(string: "\(baseURL)/dish/browse")!
        var queryItems: [URLQueryItem] = []
        if !dietaryFilters.isEmpty {
            queryItems.append(URLQueryItem(name: "dietaryFilters",
                                           value: Self.filterParam(dietaryFilters)))
        }
        if let fastingParam = fastingMode.queryParam {
            queryItems.append(URLQueryItem(name: "fastingMode", value: fastingParam))
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { return nil }
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        do {
            return try decoder.decode(BrowseResponse.self, from: data)
        } catch {
            print("APIService: browseDishes decode error: \(error)")
            return nil
        }
    }
}
