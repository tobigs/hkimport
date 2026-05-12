//
//  GarminHydrationRecord.swift
//  HKImport
//
//  Codable model for Garmin hydration log JSON records.
//  Source files: DI-Connect-Aggregator/HydrationLogFile_*.json
//
//  Note: The uuid field is a nested object: {"uuid": {"uuid": "..."}}
//

import Foundation

struct GarminHydrationRecord: Decodable {
    let userProfilePK: Int
    let calendarDate: String
    let persistedTimestampGMT: String?
    let timestampLocal: String
    let hydrationSource: String?
    /// Value in milliliters
    let valueInML: Double
    let activityId: Int?
    let capped: Bool?
    let estimatedSweatLossInML: Double?
    let duration: Double?
    /// Nested UUID object: {"uuid": "..."}
    let uuid: GarminUUID?
}

/// Wrapper for Garmin's nested UUID structure: `"uuid": {"uuid": "actual-uuid-string"}`
struct GarminUUID: Decodable {
    let uuid: String
}
