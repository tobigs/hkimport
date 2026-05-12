//
//  ActivityParser.swift
//  HKImport
//
//  Parses Garmin summarizedActivities JSON files and converts records
//  into HealthKit workouts with mapped activity types, energy, distance,
//  and custom metadata.
//

import Foundation
import HealthKit
import os.log

struct ActivityParser: GarminParser {
    typealias RecordType = GarminActivityRecord

    func decode(data: Data) throws -> [GarminActivityRecord] {
        let decoder = JSONDecoder()
        // The JSON is a list containing one wrapper object:
        // [{"summarizedActivitiesExport": [...]}]
        let wrappers = try decoder.decode([GarminActivityWrapper].self, from: data)
        return wrappers.flatMap { $0.summarizedActivitiesExport }
    }

    func convert(record: GarminActivityRecord) -> [HKSample] {
        let startDate = GarminTimestampParser.parseEpochMillis(record.startTimeGmt)
        let durationSeconds = record.duration / 1000.0
        let endDate = startDate.addingTimeInterval(durationSeconds)

        let workoutType = GarminActivityTypeMapper.map(record.activityType)

        // Energy burned: Garmin's `calories` field is in kilojoules, not kilocalories.
        // Divide by 4.184 to convert to kcal, then subtract BMR to get active calories only.
        var energyBurned: HKQuantity?
        if let totalKJ = record.calories, totalKJ > 0 {
            let bmrKJ = record.bmrCalories ?? 0
            let activeKcal = max((totalKJ - bmrKJ) / 4.184, 0)
            if activeKcal > 0 {
                energyBurned = HKQuantity(unit: .kilocalorie(), doubleValue: activeKcal)
            }
        }

        // Distance: values in the export are unreliable (wrong units for indoor activities).
        // Skip distance entirely to avoid importing garbage data.
        let totalDistance: HKQuantity? = nil

        // Custom metadata: activityType, activityId, name
        let additional: [String: Any] = [
            "GarminConnectActivityType": record.activityType,
            "GarminConnectActivityId": record.activityId,
            "GarminConnectActivityName": record.name ?? ""
        ]

        let metadata = GarminDeviceFactory.metadata(
            userProfilePK: record.userProfileId,
            additional: additional
        )
        let device = GarminDeviceFactory.device

        let workout = HKWorkout(
            activityType: workoutType,
            start: startDate,
            end: endDate,
            duration: durationSeconds,
            totalEnergyBurned: energyBurned,
            totalDistance: totalDistance,
            device: device,
            metadata: metadata
        )

        return [workout]
    }
}
