//
//  GarminHealthStatusRecord.swift
//  HKImport
//
//  Codable model for Garmin health status data JSON records.
//  Source files: DI-Connect-Wellness/*_healthStatusData.json
//

import Foundation

struct GarminHealthStatusRecord: Decodable {
    let calendarDate: String
    let createTimestampUTC: String
    let updateTimestampUTC: String?
    let outliersCount: Int?
    let metrics: [GarminHealthMetric]
}

struct GarminHealthMetric: Decodable {
    /// Metric type: "HRV", "HR", "SPO2", "RESPIRATION", "SKIN_TEMP_C"
    let type: String
    /// The metric value — null when status is "UNKNOWN"
    let value: Double?
    let baselineUpperLimit: Double?
    let baselineLowerLimit: Double?
    let status: String?
    let percentage: Double?
    let feedbackKey: String?
}
