import Foundation
import SwiftData

// MARK: - FavoriteDish model

@Model
class FavoriteDish {
    var foodCode: String
    var dishName: String
    var dateAdded: Date

    init(foodCode: String, dishName: String, dateAdded: Date = Date()) {
        self.foodCode  = foodCode
        self.dishName  = dishName
        self.dateAdded = dateAdded
    }
}
