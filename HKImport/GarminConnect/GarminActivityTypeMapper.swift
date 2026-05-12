//
//  GarminActivityTypeMapper.swift
//  HKImport
//
//  Maps Garmin activity type strings to HKWorkoutActivityType.
//  Unknown/unmapped types default to .other.
//

import HealthKit

struct GarminActivityTypeMapper {

    private static let mapping: [String: HKWorkoutActivityType] = [
        "running": .running,
        "treadmill_running": .running,
        "trail_running": .running,
        "cycling": .cycling,
        "indoor_cycling": .cycling,
        "gravel_cycling": .cycling,
        "virtual_ride": .cycling,
        "swimming": .swimming,
        "open_water_swimming": .swimming,
        "lap_swimming": .swimming,
        "strength_training": .traditionalStrengthTraining,
        "indoor_cardio": .traditionalStrengthTraining,
        "walking": .walking,
        "hiking": .hiking,
        "elliptical": .elliptical,
        "yoga": .yoga
    ]

    /// Returns the mapped HKWorkoutActivityType for a Garmin activity type string.
    /// Performs case-insensitive lookup. Returns `.other` for unknown types.
    static func map(_ garminType: String) -> HKWorkoutActivityType {
        return mapping[garminType.lowercased()] ?? .other
    }
}
