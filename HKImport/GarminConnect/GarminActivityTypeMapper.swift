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
        "ultra_run": .running,
        "cycling": .cycling,
        "indoor_cycling": .cycling,
        "gravel_cycling": .cycling,
        "virtual_ride": .cycling,
        "road_biking": .cycling,
        "swimming": .swimming,
        "open_water_swimming": .swimming,
        "lap_swimming": .swimming,
        "strength_training": .traditionalStrengthTraining,
        "indoor_cardio": .mixedCardio,
        "hiit": .highIntensityIntervalTraining,
        "walking": .walking,
        "hiking": .hiking,
        "mountaineering": .hiking,
        "elliptical": .elliptical,
        "yoga": .yoga,
        "resort_skiing": .downhillSkiing,
        "backcountry_skiing": .crossCountrySkiing,
        "soccer": .soccer,
        "stair_climbing": .stairClimbing,
        "multi_sport": .mixedCardio,
        "bouldering": .climbing,
        "table_tennis": .tableTennis,
        "indoor_rowing": .rowing,
        "transition_v2": .transition,
    ]

    /// Returns the mapped HKWorkoutActivityType for a Garmin activity type string.
    /// Performs case-insensitive lookup. Returns `.other` for unknown types.
    static func map(_ garminType: String) -> HKWorkoutActivityType {
        return mapping[garminType.lowercased()] ?? .other
    }
}
