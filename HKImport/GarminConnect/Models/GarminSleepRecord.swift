//
//  GarminSleepRecord.swift
//  HKImport
//
//  Codable model for Garmin sleep data JSON records.
//  Source files: DI-Connect-Wellness/*_sleepData.json
//

import Foundation

struct GarminSleepRecord: Decodable {
    let sleepStartTimestampGMT: String?
    let sleepEndTimestampGMT: String?
    let calendarDate: String?
    let deepSleepSeconds: Int?
    let lightSleepSeconds: Int?
    /// May be absent entirely in short sleep sessions — not just zero, but missing from JSON.
    let remSleepSeconds: Int?
    let awakeSleepSeconds: Int?
    let unmeasurableSeconds: Int?
    let sleepWindowConfirmationType: String?
    let averageRespiration: Double?
    let lowestRespiration: Double?
    let highestRespiration: Double?
    let avgSleepStress: Double?
    let restlessMomentCount: Int?
}
