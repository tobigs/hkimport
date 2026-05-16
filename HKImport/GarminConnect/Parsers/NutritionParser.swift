import Foundation
import HealthKit
import os.log

struct NutritionParser: GarminParser {
    typealias RecordType = GarminNutritionRecord

    func decode(data: Data) throws -> [GarminNutritionRecord] {
        let decoder = JSONDecoder()
        return try decoder.decode([GarminNutritionRecord].self, from: data)
    }

    func convert(record: GarminNutritionRecord) -> [HKSample] {
        guard let mfp = record.mfpCalorie, mfp.calorie > 0 else { return [] }

        guard let date = GarminTimestampParser.parseCalendarDate(record.calendarDate) else {
            return []
        }

        let endDate = date.addingTimeInterval(24 * 60 * 60)
        let metadata = GarminDeviceFactory.metadata(calendarDate: record.calendarDate)

        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: mfp.calorie)
        let sample = HKQuantitySample(
            type: HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
            quantity: quantity,
            start: date,
            end: endDate,
            device: GarminDeviceFactory.device,
            metadata: metadata
        )

        return [sample]
    }
}
