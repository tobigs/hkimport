//
//  HealthStatusParser.swift
//  HKImport
//
//  Parses Garmin health status data JSON and converts metrics
//  (HRV, HR, SpO2, Respiration) into HealthKit quantity samples.
//

import HealthKit
import os.log

struct HealthStatusParser: GarminParser {
    typealias RecordType = GarminHealthStatusRecord

    private static let log = OSLog(subsystem: "com.hkimport", category: "HealthStatusParser")

    // MARK: - GarminParser

    func decode(data: Data) throws -> [GarminHealthStatusRecord] {
        let decoder = JSONDecoder()
        return try decoder.decode([GarminHealthStatusRecord].self, from: data)
    }

    func convert(record: GarminHealthStatusRecord) -> [HKSample] {
        guard let date = GarminTimestampParser.parseGMT(record.createTimestampUTC) else {
            os_log("Failed to parse createTimestampUTC: %{public}@", log: Self.log, type: .default, record.createTimestampUTC)
            return []
        }

        let metadata = GarminDeviceFactory.metadata(calendarDate: record.calendarDate)
        var samples: [HKSample] = []

        for metric in record.metrics {
            guard let value = metric.value else {
                continue
            }

            guard let (quantityType, unit, convertedValue) = mapMetric(type: metric.type, value: value) else {
                continue
            }

            let quantity = HKQuantity(unit: unit, doubleValue: convertedValue)
            let sample = HKQuantitySample(
                type: quantityType,
                quantity: quantity,
                start: date,
                end: date,
                device: GarminDeviceFactory.device,
                metadata: metadata
            )
            samples.append(sample)
        }

        return samples
    }

    // MARK: - Private

    /// Maps a Garmin metric type and value to the corresponding HealthKit quantity type, unit, and converted value.
    /// Returns nil for unsupported metric types (e.g. SKIN_TEMP_C).
    private func mapMetric(type: String, value: Double) -> (HKQuantityType, HKUnit, Double)? {
        switch type {
        case "HRV":
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
            return (quantityType, .secondUnit(with: .milli), value)

        case "HR":
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
            let unit = HKUnit.count().unitDivided(by: .minute())
            return (quantityType, unit, value)

        case "SPO2":
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else { return nil }
            return (quantityType, .percent(), value / 100.0)

        case "RESPIRATION":
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else { return nil }
            let unit = HKUnit.count().unitDivided(by: .minute())
            return (quantityType, unit, value)

        default:
            // Skip unsupported metric types (e.g. SKIN_TEMP_C)
            return nil
        }
    }
}
