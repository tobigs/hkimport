//
//  HydrationParser.swift
//  HKImport
//
//  Parses Garmin HydrationLogFile JSON and converts records to
//  HKQuantitySample of type DietaryWater in milliliters.
//  Records with valueInML <= 0 are skipped.
//

import HealthKit
import os.log

struct HydrationParser: GarminParser {
    typealias RecordType = GarminHydrationRecord

    private static let logger = OSLog(subsystem: "com.hkimport", category: "HydrationParser")

    // MARK: - GarminParser

    func decode(data: Data) throws -> [GarminHydrationRecord] {
        let decoder = JSONDecoder()
        return try decoder.decode([GarminHydrationRecord].self, from: data)
    }

    func convert(record: GarminHydrationRecord) -> [HKSample] {
        // Skip records with zero or negative hydration values
        guard record.valueInML > 0 else {
            return []
        }

        // Parse the local timestamp for the sample date
        guard let date = GarminTimestampParser.parseLocal(record.timestampLocal) else {
            os_log("Failed to parse timestampLocal: %{public}@", log: Self.logger, type: .error, record.timestampLocal)
            return []
        }

        // Build metadata with hydrationSource and uuid
        var additional: [String: Any] = [:]
        if let source = record.hydrationSource {
            additional["GarminConnectHydrationSource"] = source
        }

        let metadata = GarminDeviceFactory.metadata(
            uuid: record.uuid?.uuid,
            calendarDate: record.calendarDate,
            userProfilePK: record.userProfilePK,
            additional: additional.isEmpty ? nil : additional
        )

        // Create DietaryWater quantity sample (point-in-time: start == end)
        let quantity = HKQuantity(unit: HKUnit.literUnit(with: .milli), doubleValue: record.valueInML)
        let sample = HKQuantitySample(
            type: HKQuantityType.quantityType(forIdentifier: .dietaryWater)!,
            quantity: quantity,
            start: date,
            end: date,
            device: GarminDeviceFactory.device,
            metadata: metadata
        )

        return [sample]
    }
}
