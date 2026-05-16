import Foundation
import HealthKit
import os.log

struct BiometricParser: GarminParser {
    typealias RecordType = GarminBiometricRecord

    func decode(data: Data) throws -> [GarminBiometricRecord] {
        let decoder = JSONDecoder()
        return try decoder.decode([GarminBiometricRecord].self, from: data)
    }

    func convert(record: GarminBiometricRecord) -> [HKSample] {
        guard let weightEntry = record.weight else { return [] }

        guard let timestampStr = weightEntry.timestampGMT,
              let date = GarminTimestampParser.parseGMT(timestampStr) else {
            return []
        }

        // Weight is in grams, convert to kg
        let kg = weightEntry.weight / 1000.0
        guard kg > 20 && kg < 300 else { return [] }

        let metadata = GarminDeviceFactory.metadata(
            calendarDate: record.metaData?.calendarDate,
            userProfilePK: record.metaData?.userProfilePK
        )

        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample = HKQuantitySample(
            type: HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
            quantity: quantity,
            start: date,
            end: date,
            device: GarminDeviceFactory.device,
            metadata: metadata
        )

        return [sample]
    }
}
