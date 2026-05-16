//
//  UDSParser.swift
//  HKImport
//
//  Parses Garmin UDS (User Daily Summary) JSON files and converts records
//  into HealthKit quantity samples for steps, distance, calories, resting HR,
//  and flights climbed.
//

import Foundation
import HealthKit
import os.log

struct UDSParser: GarminParser {
    typealias RecordType = GarminUDSRecord

    func decode(data: Data) throws -> [GarminUDSRecord] {
        let decoder = JSONDecoder()
        return try decoder.decode([GarminUDSRecord].self, from: data)
    }

    func convert(record: GarminUDSRecord) -> [HKSample] {
        // Parse start and end timestamps. Fall back to calendarDate (full-day span)
        // when wellness timestamps are null (e.g. future-dated placeholder records).
        let startDate: Date
        let endDate: Date
        if let startString = record.wellnessStartTimeLocal,
           let endString = record.wellnessEndTimeLocal,
           let parsedStart = GarminTimestampParser.parseLocal(startString),
           let parsedEnd = GarminTimestampParser.parseLocal(endString) {
            startDate = parsedStart
            endDate = parsedEnd
        } else if let calendarDate = GarminTimestampParser.parseCalendarDate(record.calendarDate) {
            startDate = calendarDate
            endDate = calendarDate.addingTimeInterval(24 * 60 * 60)
        } else {
            os_log("UDSParser: skipping record for %{public}@ — no usable timestamps",
                   log: .default, type: .info, record.calendarDate)
            return []
        }

        let metadata = GarminDeviceFactory.metadata(
            uuid: record.uuid,
            calendarDate: record.calendarDate,
            userProfilePK: record.userProfilePK
        )
        let device = GarminDeviceFactory.device

        var samples: [HKSample] = []

        // StepCount
        if let steps = record.totalSteps, steps > 0 {
            let quantity = HKQuantity(unit: .count(), doubleValue: Double(steps))
            let sample = HKQuantitySample(
                type: HKQuantityType.quantityType(forIdentifier: .stepCount)!,
                quantity: quantity,
                start: startDate,
                end: endDate,
                device: device,
                metadata: metadata
            )
            samples.append(sample)
        }

        // DistanceWalkingRunning (meters → kilometers)
        if let distanceMeters = record.totalDistanceMeters, distanceMeters > 0 {
            let km = Double(distanceMeters) / 1_000.0
            let quantity = HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: km)
            let sample = HKQuantitySample(
                type: HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
                quantity: quantity,
                start: startDate,
                end: endDate,
                device: device,
                metadata: metadata
            )
            samples.append(sample)
        }

        // ActiveEnergyBurned
        if let activeCal = record.activeKilocalories, activeCal > 0 {
            let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: activeCal)
            let sample = HKQuantitySample(
                type: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
                quantity: quantity,
                start: startDate,
                end: endDate,
                device: device,
                metadata: metadata
            )
            samples.append(sample)
        }

        // BasalEnergyBurned
        if let bmrCal = record.bmrKilocalories, bmrCal > 0 {
            let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: bmrCal)
            let sample = HKQuantitySample(
                type: HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!,
                quantity: quantity,
                start: startDate,
                end: endDate,
                device: device,
                metadata: metadata
            )
            samples.append(sample)
        }

        // RestingHeartRate (Garmin's 7-day rolling average)
        if let restingHR = record.restingHeartRate, restingHR > 0, restingHR < 120 {
            let unit = HKUnit.count().unitDivided(by: .minute())
            let quantity = HKQuantity(unit: unit, doubleValue: Double(restingHR))
            let sample = HKQuantitySample(
                type: HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
                quantity: quantity,
                start: startDate,
                end: endDate,
                device: device,
                metadata: metadata
            )
            samples.append(sample)
        }

        // FlightsClimbed (floorsAscendedInMeters / 3.0, rounded)
        if let floorsMeters = record.floorsAscendedInMeters, floorsMeters > 0 {
            let flights = (floorsMeters / 3.0).rounded()
            if flights > 0 {
                let quantity = HKQuantity(unit: .count(), doubleValue: flights)
                let sample = HKQuantitySample(
                    type: HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!,
                    quantity: quantity,
                    start: startDate,
                    end: endDate,
                    device: device,
                    metadata: metadata
                )
                samples.append(sample)
            }
        }

        return samples
    }
}
