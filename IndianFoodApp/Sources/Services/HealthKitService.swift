import HealthKit
import Foundation

class HealthKitService: ObservableObject {
    private let store = HKHealthStore()
    @Published var isAuthorized = false

    // Data types we write
    private let writeTypes: Set<HKSampleType> = [
        HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
        HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
        HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
        HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!,
        HKObjectType.quantityType(forIdentifier: .dietaryFiber)!,
    ]

    static let shared = HealthKitService()

    private init() {
        checkAuthorization()
    }

    // MARK: - Authorization

    func checkAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        isAuthorized = writeTypes.allSatisfy {
            store.authorizationStatus(for: $0) == .sharingAuthorized
        }
    }

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: [])
            await MainActor.run { checkAuthorization() }
            return isAuthorized
        } catch {
            print("HealthKit auth error: \(error)")
            return false
        }
    }

    // MARK: - Write meal to HealthKit

    func logMeal(
        dishName: String,
        kcal:     Double,
        protein:  Double,
        carbs:    Double,
        fat:      Double,
        fibre:    Double,
        date:     Date = Date()
    ) async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        let metadata: [String: Any] = [HKMetadataKeyFoodType: dishName]

        let samples: [HKQuantitySample] = [
            makeSample(.dietaryEnergyConsumed, value: kcal,    unit: .kilocalorie(), date: date, metadata: metadata),
            makeSample(.dietaryProtein,        value: protein, unit: .gram(),        date: date, metadata: metadata),
            makeSample(.dietaryCarbohydrates,  value: carbs,   unit: .gram(),        date: date, metadata: metadata),
            makeSample(.dietaryFatTotal,       value: fat,     unit: .gram(),        date: date, metadata: metadata),
            makeSample(.dietaryFiber,          value: fibre,   unit: .gram(),        date: date, metadata: metadata),
        ]

        do {
            try await store.save(samples)
            print("HealthKit: logged \(dishName) — \(Int(kcal)) kcal")
            return true
        } catch {
            print("HealthKit: save error: \(error)")
            return false
        }
    }

    // MARK: - Private helpers

    private func makeSample(
        _ identifier: HKQuantityTypeIdentifier,
        value:    Double,
        unit:     HKUnit,
        date:     Date,
        metadata: [String: Any]
    ) -> HKQuantitySample {
        let type     = HKQuantityType(identifier)
        let quantity = HKQuantity(unit: unit, doubleValue: value)
        return HKQuantitySample(
            type:     type,
            quantity: quantity,
            start:    date,
            end:      date,
            metadata: metadata
        )
    }
}
