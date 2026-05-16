import Foundation

struct GarminNutritionRecord: Decodable {
    let calendarDate: String
    let mfpCalorie: GarminMfpCalorie?
}

struct GarminMfpCalorie: Decodable {
    let calorie: Double
    let calorieGoal: Double?
}
