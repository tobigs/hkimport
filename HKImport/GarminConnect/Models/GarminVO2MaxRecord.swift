//
//  GarminVO2MaxRecord.swift
//  HKImport
//
//  Codable models for Garmin VO2Max data from two sources:
//  - MetricsMaxMetData files (DI-Connect-Metrics/MetricsMaxMetData_*.json)
//  - ActivityVo2Max files (DI-Connect-Metrics/ActivityVo2Max_*.json)
//

import Foundation

/// VO2Max record from MetricsMaxMetData files.
/// Uses `updateTimestamp` for the sample date.
struct GarminVO2MaxRecord: Decodable {
    let userProfilePK: Int
    let calendarDate: String
    let deviceId: Int?
    let updateTimestamp: String
    let sport: String
    let subSport: String?
    let vo2MaxValue: Double?
    let maxMet: Double?
    let maxMetCategory: String?
    let calibratedData: Int?
}

/// VO2Max record from ActivityVo2Max files.
/// Uses `timestampGmt` for the sample date.
struct GarminActivityVO2MaxRecord: Decodable {
    let userProfilePK: Int
    let calendarDate: String
    let deviceId: Int?
    let timestampGmt: String
    let sport: String
    let subSport: String?
    let activityId: Int?
    let activityUuid: GarminUUID?
    let vo2MaxValue: Double?
}
