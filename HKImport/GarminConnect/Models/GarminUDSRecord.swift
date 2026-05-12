//
//  GarminUDSRecord.swift
//  HKImport
//
//  Codable model for Garmin UDS (User Daily Summary) JSON records.
//  Source files: DI-Connect-Aggregator/UDSFile_*.json
//

import Foundation

struct GarminUDSRecord: Decodable {
    let userProfilePK: Int
    let calendarDate: String
    let uuid: String?
    let totalSteps: Int?
    let totalDistanceMeters: Int?
    let activeKilocalories: Double?
    let bmrKilocalories: Double?
    let wellnessStartTimeLocal: String?
    let wellnessEndTimeLocal: String?
    let wellnessStartTimeGmt: String?
    let wellnessEndTimeGmt: String?
    let minHeartRate: Int?
    let maxHeartRate: Int?
    let restingHeartRate: Int?
    let currentDayRestingHeartRate: Int?
    /// The minimum average heart rate (used as resting HR for HealthKit import)
    let minAvgHeartRate: Int?
    /// Floors ascended expressed in meters (1 flight ≈ 3 meters)
    let floorsAscendedInMeters: Double?
    let floorsDescendedInMeters: Double?
    let userFloorsAscendedGoal: Int?
    let moderateIntensityMinutes: Int?
    let vigorousIntensityMinutes: Int?
    let highlyActiveSeconds: Int?
    let activeSeconds: Int?
    let includesAllDayPulseOx: Bool?
    let includesSleepPulseOx: Bool?
    let totalKilocalories: Double?
    let durationInMilliseconds: Int?
}
