//
//  VO2MaxParser.swift
//  HKImport
//
//  Parsers for Garmin VO2Max data from two sources:
//  - MetricsMaxMetData files (parsed by VO2MaxParser)
//  - ActivityVo2Max files (parsed by ActivityVO2MaxParser)
//  Both produce HKQuantitySample of type VO2Max in mL/(kg·min).
//

import HealthKit
import os.log

/// Parses MetricsMaxMetData JSON files into VO2Max HKQuantitySamples.
/// Uses `updateTimestamp` for the sample date.
struct VO2MaxParser: GarminParser {
    typealias RecordType = GarminVO2MaxRecord

    func decode(data: Data) throws -> [GarminVO2MaxRecord] {
        let decoder = JSONDecoder()
        return try decoder.decode([GarminVO2MaxRecord].self, from: data)
    }

    func convert(record: GarminVO2MaxRecord) -> [HKSample] {
        guard let vo2Max = record.vo2MaxValue else {
            return []
        }

        guard let date = GarminTimestampParser.parseGMT(record.updateTimestamp) else {
            os_log("VO2MaxParser: Failed to parse updateTimestamp: %{public}@", record.updateTimestamp)
            return []
        }

        let unit = HKUnit(from: "ml/(kg*min)")
        let quantity = HKQuantity(unit: unit, doubleValue: vo2Max)

        var additional: [String: Any] = [
            "GarminConnectSport": record.sport
        ]
        if let subSport = record.subSport {
            additional["GarminConnectSubSport"] = subSport
        }

        let metadata = GarminDeviceFactory.metadata(
            calendarDate: record.calendarDate,
            userProfilePK: record.userProfilePK,
            additional: additional
        )

        let sample = HKQuantitySample(
            type: HKQuantityType.quantityType(forIdentifier: .vo2Max)!,
            quantity: quantity,
            start: date,
            end: date,
            device: GarminDeviceFactory.device,
            metadata: metadata
        )

        return [sample]
    }
}

/// Parses ActivityVo2Max JSON files into VO2Max HKQuantitySamples.
/// Uses `timestampGmt` for the sample date.
struct ActivityVO2MaxParser: GarminParser {
    typealias RecordType = GarminActivityVO2MaxRecord

    func decode(data: Data) throws -> [GarminActivityVO2MaxRecord] {
        let decoder = JSONDecoder()
        return try decoder.decode([GarminActivityVO2MaxRecord].self, from: data)
    }

    func convert(record: GarminActivityVO2MaxRecord) -> [HKSample] {
        guard let vo2Max = record.vo2MaxValue else {
            return []
        }

        guard let date = GarminTimestampParser.parseGMT(record.timestampGmt) else {
            os_log("ActivityVO2MaxParser: Failed to parse timestampGmt: %{public}@", record.timestampGmt)
            return []
        }

        let unit = HKUnit(from: "ml/(kg*min)")
        let quantity = HKQuantity(unit: unit, doubleValue: vo2Max)

        var additional: [String: Any] = [
            "GarminConnectSport": record.sport
        ]
        if let subSport = record.subSport {
            additional["GarminConnectSubSport"] = subSport
        }

        let metadata = GarminDeviceFactory.metadata(
            calendarDate: record.calendarDate,
            userProfilePK: record.userProfilePK,
            additional: additional
        )

        let sample = HKQuantitySample(
            type: HKQuantityType.quantityType(forIdentifier: .vo2Max)!,
            quantity: quantity,
            start: date,
            end: date,
            device: GarminDeviceFactory.device,
            metadata: metadata
        )

        return [sample]
    }
}
