import Foundation

// MARK: - Open Food Facts models

struct OFFProduct: Codable {
    let productName: String?
    let brands:      String?
    let nutriments:  OFFNutriments?
    let servingSize: String?
    let imageURL:    String?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case nutriments
        case servingSize = "serving_size"
        case imageURL    = "image_url"
    }
}

struct OFFNutriments: Codable {
    let energyKcal100g:       Double?
    let proteins100g:         Double?
    let carbohydrates100g:    Double?
    let fat100g:              Double?
    let fiber100g:            Double?
    let energyKcalServing:    Double?
    let proteinsServing:      Double?
    let carbohydratesServing: Double?
    let fatServing:           Double?
    let fiberServing:         Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g       = "energy-kcal_100g"
        case proteins100g         = "proteins_100g"
        case carbohydrates100g    = "carbohydrates_100g"
        case fat100g              = "fat_100g"
        case fiber100g            = "fiber_100g"
        case energyKcalServing    = "energy-kcal_serving"
        case proteinsServing      = "proteins_serving"
        case carbohydratesServing = "carbohydrates_serving"
        case fatServing           = "fat_serving"
        case fiberServing         = "fiber_serving"
    }
}

struct OFFResponse: Codable {
    let status:  Int
    let product: OFFProduct?
}

// MARK: - Normalized result

struct BarcodeResult {
    let barcode:         String
    let productName:     String
    let brand:           String
    let kcalPer100g:     Double
    let proteinPer100g:  Double
    let carbsPer100g:    Double
    let fatPer100g:      Double
    let fibrePer100g:    Double
    let servingSize:     String?
    let kcalPerServing:  Double?
    let proteinPerServing: Double?
    let carbsPerServing:   Double?
    let fatPerServing:     Double?
    let fibrePerServing:   Double?
}

// MARK: - Service

class OpenFoodFactsService {
    static let shared = OpenFoodFactsService()
    private let session = URLSession.shared
    private let baseURL = "https://world.openfoodfacts.org/api/v0/product"

    func lookup(barcode: String) async -> BarcodeResult? {
        guard let url = URL(string: "\(baseURL)/\(barcode).json") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("CalorieScan iOS App - contact@caloriescan.app",
                         forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(OFFResponse.self, from: data)
            guard decoded.status == 1, let product = decoded.product else {
                print("OFF: product not found for barcode \(barcode)")
                return nil
            }
            return normalize(barcode: barcode, product: product)
        } catch {
            print("OFF: lookup error: \(error)")
            return nil
        }
    }

    private func normalize(barcode: String, product: OFFProduct) -> BarcodeResult? {
        let n    = product.nutriments
        let kcal = n?.energyKcal100g ?? n?.energyKcalServing
        guard let kcal else {
            print("OFF: no calorie data for \(barcode)")
            return nil
        }
        return BarcodeResult(
            barcode:          barcode,
            productName:      product.productName ?? "Unknown Product",
            brand:            product.brands ?? "",
            kcalPer100g:      n?.energyKcal100g ?? kcal,
            proteinPer100g:   n?.proteins100g ?? 0,
            carbsPer100g:     n?.carbohydrates100g ?? 0,
            fatPer100g:       n?.fat100g ?? 0,
            fibrePer100g:     n?.fiber100g ?? 0,
            servingSize:      product.servingSize,
            kcalPerServing:   n?.energyKcalServing,
            proteinPerServing: n?.proteinsServing,
            carbsPerServing:  n?.carbohydratesServing,
            fatPerServing:    n?.fatServing,
            fibrePerServing:  n?.fiberServing
        )
    }
}
