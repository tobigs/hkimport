//
//  GarminActivityRecord.swift
//  HKImport
//
//  Codable model for Garmin summarized activities JSON records.
//  Source files: DI-Connect-Fitness/*_summarizedActivities.json
//
//  Note: The JSON is wrapped in {"summarizedActivitiesExport": [...]} — NOT a top-level array.
//

import Foundation

/// Top-level wrapper for the summarizedActivities JSON structure.
struct GarminActivityWrapper: Decodable {
    let summarizedActivitiesExport: [GarminActivityRecord]
}

struct GarminActivityRecord: Decodable {
    let activityId: Int
    let name: String?
    let activityType: String
    let userProfileId: Int?
    /// Start time as epoch milliseconds (Double)
    let startTimeGmt: Double
    /// Start time local as epoch milliseconds (Double)
    let startTimeLocal: Double?
    /// Duration in milliseconds (Double)
    let duration: Double
    /// Distance in meters
    let distance: Double?
    /// Calories burned (kilocalories) — includes BMR; subtract bmrCalories for active only
    let calories: Double?
    /// Basal metabolic rate calories included in the `calories` total
    let bmrCalories: Double?
    let avgHr: Double?
    let maxHr: Double?
    let avgSpeed: Double?
    let maxSpeed: Double?
    let elevationGain: Double?
    let elevationLoss: Double?
    let sportType: String?
    let vO2MaxValue: Double?
}
